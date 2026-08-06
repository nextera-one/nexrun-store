package one.nextera.nexrun.store.catalog;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Keeps the site self-contained.
 *
 * <p>The Store's subject is verifiable trust, so it must not load a stylesheet,
 * font or script from a third-party CDN at runtime: that leaks every viewer's
 * IP address and breaks the page on an air-gapped host. Outbound <em>links</em>
 * are fine — those are navigations the reader chooses. What is banned is a
 * subresource the browser fetches on its own.
 */
class OfflineAssetsTest {

    private static final Path RESOURCES = Path.of("src/main/resources");
    private static final String ICON_SUBSET =
            "src/main/resources/icons/material-symbols/subset-icons.txt";

    /** {@code url(...)} in CSS, and src/href attributes in markup. */
    private static final Pattern CSS_URL = Pattern.compile("url\\(\\s*['\"]?([^'\")]+)");
    private static final Pattern SUBRESOURCE = Pattern.compile(
            "<(?:link|script|img|iframe|source|audio|video)\\b[^>]*?\\b(?:href|src)\\s*=\\s*[\"']([^\"']+)",
            Pattern.CASE_INSENSITIVE);

    @Test
    @DisplayName("no stylesheet loads an external subresource")
    void stylesheetsAreSelfContained() {
        List<String> offenders = new ArrayList<>();
        for (Path file : filesWithSuffix(".css")) {
            scan(file, CSS_URL, offenders);
        }
        assertTrue(offenders.isEmpty(),
                () -> "external CSS subresource(s) found — the page would not work offline "
                        + "and would leak viewer IPs:\n  " + String.join("\n  ", offenders));
    }

    @Test
    @DisplayName("no page loads an external stylesheet, script, or image")
    void pagesAreSelfContained() {
        List<String> offenders = new ArrayList<>();
        for (Path file : filesWithSuffix(".html", ".jvl")) {
            scan(file, SUBRESOURCE, offenders);
        }
        assertTrue(offenders.isEmpty(),
                () -> "external subresource(s) referenced from markup:\n  "
                        + String.join("\n  ", offenders));
    }

    @Test
    @DisplayName("the Google Fonts CDN is not referenced anywhere in served assets")
    void noGoogleFontsImport() {
        List<String> offenders = new ArrayList<>();
        for (Path file : filesWithSuffix(".css", ".html", ".jvl")) {
            String body = read(file);
            if (body.contains("fonts.googleapis.com") || body.contains("fonts.gstatic.com")) {
                offenders.add(relative(file));
            }
        }
        assertTrue(offenders.isEmpty(),
                () -> "the fonts CDN is referenced by:\n  " + String.join("\n  ", offenders)
                        + "\nRun ./tools/fetch-web-fonts.sh and serve the fonts from this origin.");
    }

    @Test
    @DisplayName("every self-hosted font referenced by CSS exists in the tree")
    void selfHostedFontFilesExist() {
        Path sheet = StoreFiles.path("src/main/resources/styles/fonts-self-hosted.css");
        Matcher matcher = CSS_URL.matcher(read(sheet));
        int found = 0;
        while (matcher.find()) {
            String reference = matcher.group(1).trim();
            Path file = StoreFiles.path("src/main/resources" + reference);
            assertTrue(Files.isRegularFile(file), "missing font file: " + reference);
            found++;
        }
        assertTrue(found >= 5,
                "expected at least 5 self-hosted faces, found " + found
                        + "; regenerate with ./tools/fetch-web-fonts.sh");
    }

    @Test
    @DisplayName("every icon used by a template is in the subset icon font")
    void everyTemplateIconIsInTheSubset() {
        Set<String> subset = new TreeSet<>();
        for (String line : read(StoreFiles.path(ICON_SUBSET)).split("\\R")) {
            String name = line.trim();
            if (!name.isEmpty() && !name.startsWith("#")) {
                subset.add(name);
            }
        }
        assertTrue(subset.size() > 10, "the icon subset manifest looks empty or malformed");

        Set<String> used = new TreeSet<>();
        // name= may sit anywhere in the tag, e.g. <j-icon class="x" name="y">.
        Pattern icon = Pattern.compile("<j-icon\\b[^>]*?\\bname=\"([a-z0-9_]+)\"");
        for (Path file : filesWithSuffix(".jvl", ".html")) {
            Matcher matcher = icon.matcher(read(file));
            while (matcher.find()) {
                used.add(matcher.group(1));
            }
        }
        assertTrue(!used.isEmpty(), "no <j-icon> usages found; this guard has gone blind");

        Set<String> missing = new TreeSet<>(used);
        missing.removeAll(subset);
        assertTrue(missing.isEmpty(),
                () -> "icon(s) used by a template but absent from the subset font: " + missing
                        + "\nThey would render as blank boxes. Re-run ./tools/fetch-web-fonts.sh.");
    }

    // ------------------------------------------------------------------

    private static void scan(Path file, Pattern pattern, List<String> offenders) {
        Matcher matcher = pattern.matcher(read(file));
        while (matcher.find()) {
            String reference = matcher.group(1).trim();
            if (isExternal(reference)) {
                offenders.add(relative(file) + " -> " + reference);
            }
        }
    }

    /** Absolute-scheme and protocol-relative references leave this origin. */
    private static boolean isExternal(String reference) {
        String value = reference.toLowerCase(java.util.Locale.ROOT);
        if (value.startsWith("//")) {
            return true;
        }
        // data: and blob: stay in the page; everything else with a scheme leaves it.
        return value.matches("^[a-z][a-z0-9+.-]*:.*")
                && !value.startsWith("data:")
                && !value.startsWith("blob:");
    }

    private static List<Path> filesWithSuffix(String... suffixes) {
        Path root = StoreFiles.path("src/main/resources/index.html").getParent();
        try (Stream<Path> walk = Files.walk(root)) {
            List<Path> files = walk.filter(Files::isRegularFile)
                    .filter(path -> {
                        String name = path.getFileName().toString();
                        for (String suffix : suffixes) {
                            if (name.endsWith(suffix)) {
                                return true;
                            }
                        }
                        return false;
                    })
                    .toList();
            if (files.isEmpty()) {
                throw new IllegalStateException("no files matched under " + root);
            }
            return files;
        } catch (IOException e) {
            throw new UncheckedIOException("Could not walk " + root, e);
        }
    }

    private static String read(Path file) {
        try {
            return Files.readString(file);
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read " + file, e);
        }
    }

    private static String relative(Path file) {
        return RESOURCES.getFileName() == null ? file.toString()
                : file.toAbsolutePath().toString();
    }
}
