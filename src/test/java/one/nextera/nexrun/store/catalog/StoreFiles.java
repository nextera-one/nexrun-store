package one.nextera.nexrun.store.catalog;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Locates repository files from a test, independent of the working directory
 * Surefire or an IDE happens to pick.
 */
final class StoreFiles {

    static final String CATALOG = "catalog/catalog.json";
    static final String SCHEMA = "schemas/catalog-entry.schema.json";

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private StoreFiles() {
    }

    /** Resolves a repository-relative path, failing loudly if it is missing. */
    static Path path(String relative) {
        Path base = baseDirectory();
        Path resolved = base.resolve(relative);
        if (!Files.isRegularFile(resolved)) {
            throw new IllegalStateException(
                    "Required repository file is missing: " + resolved.toAbsolutePath()
                            + " (resolved against " + base.toAbsolutePath() + ")");
        }
        return resolved;
    }

    static String read(String relative) {
        try {
            return Files.readString(path(relative));
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read " + relative, e);
        }
    }

    static JsonNode json(String relative) {
        try {
            return MAPPER.readTree(path(relative).toFile());
        } catch (IOException e) {
            throw new UncheckedIOException("Could not parse " + relative + " as JSON", e);
        }
    }

    static ObjectMapper mapper() {
        return MAPPER;
    }

    private static Path baseDirectory() {
        String configured = System.getProperty("nexrunStore.basedir");
        if (configured != null && !configured.isBlank()) {
            return Path.of(configured);
        }
        // Fall back to walking up from the working directory so the suite also
        // runs from an IDE that sets no basedir property.
        Path candidate = Path.of("").toAbsolutePath();
        while (candidate != null) {
            if (Files.isRegularFile(candidate.resolve(CATALOG))) {
                return candidate;
            }
            candidate = candidate.getParent();
        }
        throw new IllegalStateException(
                "Could not locate the repository root: no ancestor of "
                        + Path.of("").toAbsolutePath() + " contains " + CATALOG);
    }
}
