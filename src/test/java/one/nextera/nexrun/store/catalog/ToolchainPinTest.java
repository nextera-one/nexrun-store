package one.nextera.nexrun.store.catalog;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.fail;

/**
 * The Javelle version is pinned in three files. They drifted before — the build
 * stayed on 0.1.59 long after the release that fixed template-compiler bugs —
 * so agreement is now checked rather than remembered.
 */
class ToolchainPinTest {

    @Test
    @DisplayName("pom.xml, javelle.config.json and ci.yml pin the same Javelle version")
    void javelleVersionIsConsistent() {
        String pom = extract("pom.xml",
                Pattern.compile("<javelle\\.version>([^<]+)</javelle\\.version>"),
                "<javelle.version> in pom.xml");
        String config = extract("javelle.config.json",
                Pattern.compile("\"javelleVersion\"\\s*:\\s*\"([^\"]+)\""),
                "javelleVersion in javelle.config.json");
        String ci = extract(".github/workflows/ci.yml",
                Pattern.compile("JAVELLE_VERSION:\\s*\"?([0-9][^\"\\s]*)\"?"),
                "JAVELLE_VERSION in .github/workflows/ci.yml");

        assertEquals(pom, config,
                "javelle.config.json pins a different Javelle version than pom.xml");
        assertEquals(pom, ci,
                "the CI workflow pins a different Javelle version than pom.xml");
    }

    @Test
    @DisplayName("no file still pins the superseded 0.1.59 toolchain")
    void noStaleVersionReferences() {
        for (String file : new String[]{"pom.xml", "javelle.config.json", ".github/workflows/ci.yml"}) {
            String body = StoreFiles.read(file);
            if (body.contains("0.1.59")) {
                fail(file + " still references Javelle 0.1.59, which predates the "
                        + "JvlCompiler template-compilation fixes released in 0.1.69");
            }
        }
    }

    private static String extract(String file, Pattern pattern, String what) {
        Matcher matcher = pattern.matcher(StoreFiles.read(file));
        if (!matcher.find()) {
            fail("could not find " + what + "; the version pin guard is blind");
        }
        return matcher.group(1).trim();
    }
}
