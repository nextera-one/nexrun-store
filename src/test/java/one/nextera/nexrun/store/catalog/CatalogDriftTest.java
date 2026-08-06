package one.nextera.nexrun.store.catalog;

import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

/**
 * Guards the seam between {@code catalog/catalog.json} and the static
 * {@code .jvl} templates.
 *
 * <p>In this slice the templates are hand-written rather than rendered from the
 * catalog, so package facts exist in two places and can drift silently. They
 * already did: the MySQL page advertised a "Processes 512" limit that appeared
 * in neither the catalog nor the schema. This test makes catalog.json the
 * source of truth and fails the build when a template disagrees with it.
 *
 * <p>When a template is restructured so a probe below no longer matches, the
 * test fails rather than silently passing — a blind guard is the failure mode
 * this class exists to prevent.
 */
class CatalogDriftTest {

    private static final String HOME_PAGE =
            "src/main/resources/one/nextera/nexrun/store/pages/HomePage.jvl";
    private static final String MYSQL_PAGE =
            "src/main/resources/one/nextera/nexrun/store/pages/MysqlAppPage.jvl";

    private static final long GIB = 1024L * 1024L * 1024L;

    private static JsonNode catalog;

    @BeforeAll
    static void load() {
        catalog = StoreFiles.json(StoreFiles.CATALOG);
    }

    // ------------------------------------------------------------------
    // MysqlAppPage.jvl — the "Runtime profile" card
    // ------------------------------------------------------------------

    @Test
    @DisplayName("MySQL runtime profile card matches catalog.json")
    void mysqlRuntimeProfileMatchesCatalog() {
        JsonNode entry = entry("mysql");
        JsonNode requirements = entry.get("requirements");
        Map<String, String> profile = definitionList(StoreFiles.read(MYSQL_PAGE));

        assertTrue(profile.containsKey("Runtime"),
                "MysqlAppPage.jvl no longer has a 'Runtime' row; the drift guard is blind");
        assertEquals("oci", profile.get("Runtime").toLowerCase(Locale.ROOT).contains("oci") ? "oci" : "?",
                "template runtime disagrees with catalog requirements.runtime");
        assertEquals(requirements.get("runtime").asText(), "oci",
                "catalog runtime changed; update MysqlAppPage.jvl 'Runtime' row too");

        assertEquals(requirements.get("cpuMillis").asInt(), number(profile, "CPU"),
                "'CPU' row disagrees with catalog requirements.cpuMillis");
        assertEquals(requirements.get("memoryBytes").asLong(), gibibytes(profile, "Memory"),
                "'Memory' row disagrees with catalog requirements.memoryBytes");
        assertEquals(requirements.get("pids").asInt(), number(profile, "Processes"),
                "'Processes' row disagrees with catalog requirements.pids");
        assertEquals(requirements.get("ports").get(0).asInt(), number(profile, "Port"),
                "'Port' row disagrees with catalog requirements.ports[0]");

        List<String> templateArches = new ArrayList<>();
        for (String part : require(profile, "Architectures").split(",")) {
            templateArches.add(part.trim().toLowerCase(Locale.ROOT));
        }
        assertEquals(strings(entry.get("architectures")), templateArches,
                "'Architectures' row disagrees with catalog architectures");
    }

    @Test
    @DisplayName("MySQL volume and secret names match catalog.json")
    void mysqlInstanceConfigurationMatchesCatalog() {
        String page = StoreFiles.read(MYSQL_PAGE);
        JsonNode requirements = entry("mysql").get("requirements");

        List<String> volumes = strings(requirements.get("volumes"));
        List<String> secrets = strings(requirements.get("secrets"));

        assertEquals(volumes.size(), headingCount(page, "volumes?"),
                "the '<n> volumes' heading disagrees with catalog requirements.volumes");
        assertEquals(secrets.size(), headingCount(page, "required secrets?"),
                "the '<n> required secret' heading disagrees with catalog requirements.secrets");

        List<String> codes = matchAll(page, Pattern.compile("<code>([a-z0-9][a-z0-9-]*)</code>"));
        for (String volume : volumes) {
            assertTrue(codes.contains(volume),
                    "catalog declares volume '" + volume + "' but MysqlAppPage.jvl never names it");
        }
        for (String secret : secrets) {
            assertTrue(codes.contains(secret),
                    "catalog declares secret '" + secret + "' but MysqlAppPage.jvl never names it");
        }
    }

    @Test
    @DisplayName("MySQL page links to exactly the catalog source and documentation URLs")
    void mysqlLinksMatchCatalog() {
        String page = StoreFiles.read(MYSQL_PAGE);
        JsonNode entry = entry("mysql");
        List<String> hrefs = matchAll(page, Pattern.compile("href=\"(https://[^\"]+)\""));

        assertTrue(hrefs.contains(entry.get("source").asText()),
                "MysqlAppPage.jvl does not link to catalog source " + entry.get("source").asText());
        assertTrue(hrefs.contains(entry.get("documentation").asText()),
                "MysqlAppPage.jvl does not link to catalog documentation "
                        + entry.get("documentation").asText());
    }

    @Test
    @DisplayName("MySQL page states the catalog licence")
    void mysqlLicenceMatchesCatalog() {
        String page = StoreFiles.read(MYSQL_PAGE);
        String licence = entry("mysql").get("license").asText();
        assertTrue(page.contains(licence),
                "MysqlAppPage.jvl does not state the catalog licence " + licence);
    }

    // ------------------------------------------------------------------
    // HomePage.jvl — the seed catalog cards
    // ------------------------------------------------------------------

    @Test
    @DisplayName("home page hero counts match catalog.json")
    void heroCountsMatchCatalog() {
        String page = StoreFiles.read(HOME_PAGE);

        int sourceKits = singleInt(page, Pattern.compile("(\\d+)\\s+source kits"),
                "the '<n> source kits' hero fact");
        long expectedKits = count(catalog, e -> "source-kit".equals(e.get("availability").asText()));
        assertEquals(expectedKits, sourceKits,
                "the hero 'source kits' count disagrees with catalog.json");

        int publishers = singleInt(page, Pattern.compile("(\\d+)\\s+official publisher"),
                "the '<n> official publisher' hero fact");
        long expectedPublishers = catalog.findValuesAsText("publisher").stream().distinct().count();
        assertEquals(expectedPublishers, publishers,
                "the hero 'official publisher' count disagrees with catalog.json");
    }

    @Test
    @DisplayName("every home page package card matches its catalog entry")
    void packageCardsMatchCatalog() {
        List<String> cards = packageCards(StoreFiles.read(HOME_PAGE));
        assertEquals(catalog.size(), cards.size(),
                "HomePage.jvl shows " + cards.size() + " package cards but catalog.json has "
                        + catalog.size() + " entries");

        List<String> checked = new ArrayList<>();
        for (String card : cards) {
            String title = cardTitle(card);
            JsonNode entry = entryByName(title);
            JsonNode requirements = entry.get("requirements");
            String slug = entry.get("slug").asText();
            checked.add(slug);

            List<String> facts = specGridFacts(card, title);
            int matched = 0;

            for (String fact : facts) {
                Matcher runtime = Pattern.compile("^(OCI|Static) runtime$").matcher(fact);
                if (runtime.matches()) {
                    assertEquals(requirements.get("runtime").asText(),
                            runtime.group(1).toLowerCase(Locale.ROOT),
                            "card '" + title + "': runtime disagrees with catalog");
                    matched++;
                    continue;
                }
                Matcher memory = Pattern.compile("^(\\d+) GiB RAM$").matcher(fact);
                if (memory.matches()) {
                    assertEquals(requirements.get("memoryBytes").asLong(),
                            Long.parseLong(memory.group(1)) * GIB,
                            "card '" + title + "': memory disagrees with catalog");
                    matched++;
                    continue;
                }
                Matcher port = Pattern.compile("^Port (\\d+)$").matcher(fact);
                if (port.matches()) {
                    assertEquals(requirements.get("ports").get(0).asInt(),
                            Integer.parseInt(port.group(1)),
                            "card '" + title + "': port disagrees with catalog");
                    matched++;
                    continue;
                }
                Integer volumes = countFact(fact, "volumes?");
                if (volumes != null) {
                    assertEquals(requirements.get("volumes").size(), volumes.intValue(),
                            "card '" + title + "': volume count disagrees with catalog");
                    matched++;
                    continue;
                }
                Integer secrets = countFact(fact, "secrets?");
                if (secrets != null) {
                    assertEquals(requirements.get("secrets").size(), secrets.intValue(),
                            "card '" + title + "': secret count disagrees with catalog");
                    matched++;
                }
            }

            assertTrue(matched >= 3, "card '" + title + "': only " + matched
                    + " comparable facts were recognised in its spec grid ("
                    + facts + "); the drift guard has gone blind on this card");
        }

        for (JsonNode entry : catalog) {
            assertTrue(checked.contains(entry.get("slug").asText()),
                    "catalog entry '" + entry.get("slug").asText()
                            + "' has no matching HomePage.jvl card");
        }
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    private static JsonNode entry(String slug) {
        for (JsonNode entry : catalog) {
            if (slug.equals(entry.path("slug").asText())) {
                return entry;
            }
        }
        return fail("catalog.json has no entry with slug '" + slug + "'");
    }

    private static JsonNode entryByName(String title) {
        for (JsonNode entry : catalog) {
            String name = entry.path("name").asText();
            if (title.equals(name) || title.startsWith(name + " ")) {
                return entry;
            }
        }
        return fail("HomePage.jvl shows a card titled '" + title
                + "' with no matching catalog.json entry");
    }

    /** Parses the {@code <dt>Label</dt><dd>Value</dd>} rows of the requirement card. */
    private static Map<String, String> definitionList(String page) {
        Map<String, String> rows = new LinkedHashMap<>();
        Matcher matcher = Pattern.compile(
                        "<dt>(?:.*?</j-icon>)?\\s*([^<>]+?)\\s*</dt>\\s*<dd>\\s*([^<>]+?)\\s*</dd>",
                        Pattern.DOTALL)
                .matcher(page);
        while (matcher.find()) {
            rows.put(matcher.group(1), matcher.group(2));
        }
        if (rows.isEmpty()) {
            fail("no <dt>/<dd> requirement rows found; MysqlAppPage.jvl structure changed "
                    + "and the drift guard can no longer see package facts");
        }
        return rows;
    }

    private static String require(Map<String, String> rows, String label) {
        String value = rows.get(label);
        if (value == null) {
            fail("MysqlAppPage.jvl no longer has a '" + label
                    + "' row; the drift guard is blind to that fact");
        }
        return value;
    }

    /** Reads a row such as {@code 2,000 millicores} or {@code TCP 3306} as an int. */
    private static int number(Map<String, String> rows, String label) {
        String value = require(rows, label);
        Matcher matcher = Pattern.compile("([0-9][0-9,]*)").matcher(value);
        if (!matcher.find()) {
            fail("the '" + label + "' row ('" + value + "') contains no number to compare");
        }
        return Integer.parseInt(matcher.group(1).replace(",", ""));
    }

    /** Reads a row such as {@code 2 GiB} as a byte count. */
    private static long gibibytes(Map<String, String> rows, String label) {
        String value = require(rows, label);
        Matcher matcher = Pattern.compile("([0-9]+)\\s*GiB").matcher(value);
        if (!matcher.find()) {
            fail("the '" + label + "' row ('" + value + "') is not expressed in GiB");
        }
        return Long.parseLong(matcher.group(1)) * GIB;
    }

    private static int headingCount(String page, String noun) {
        return singleInt(page, Pattern.compile("<h2>\\s*(\\d+)\\s+" + noun + "\\s*</h2>"),
                "the '<n> " + noun + "' heading");
    }

    private static int singleInt(String text, Pattern pattern, String what) {
        Matcher matcher = pattern.matcher(text);
        if (!matcher.find()) {
            fail(what + " was not found; the template changed and the drift guard is blind");
        }
        return Integer.parseInt(matcher.group(1));
    }

    /** {@code "2 volumes"} to 2, {@code "No secrets"} to 0, otherwise null. */
    private static Integer countFact(String fact, String noun) {
        Matcher numeric = Pattern.compile("^(\\d+) " + noun + "$").matcher(fact);
        if (numeric.matches()) {
            return Integer.valueOf(numeric.group(1));
        }
        if (Pattern.compile("^No " + noun + "$").matcher(fact).matches()) {
            return 0;
        }
        return null;
    }

    private static List<String> packageCards(String page) {
        List<String> cards = new ArrayList<>();
        Matcher matcher = Pattern.compile(
                        "<j-card class=\"package-card[^\"]*\">(.*?)</j-card>", Pattern.DOTALL)
                .matcher(page);
        while (matcher.find()) {
            cards.add(matcher.group(1));
        }
        if (cards.isEmpty()) {
            fail("no package cards found in HomePage.jvl; the drift guard is blind");
        }
        return cards;
    }

    private static String cardTitle(String card) {
        Matcher matcher = Pattern.compile("<h3>(.*?)</h3>", Pattern.DOTALL).matcher(card);
        if (!matcher.find()) {
            fail("a HomePage.jvl package card has no <h3> title");
        }
        return matcher.group(1).replaceAll("<[^>]*>", "").replaceAll("\\s+", " ").trim();
    }

    private static List<String> specGridFacts(String card, String title) {
        Matcher grid = Pattern.compile("<div class=\"spec-grid\"[^>]*>(.*?)</div>", Pattern.DOTALL)
                .matcher(card);
        if (!grid.find()) {
            fail("card '" + title + "' has no spec grid; the drift guard is blind to it");
        }
        List<String> facts = matchAll(grid.group(1),
                Pattern.compile("</j-icon>\\s*([^<]+?)\\s*</span>"));
        if (facts.isEmpty()) {
            fail("card '" + title + "' has an unreadable spec grid");
        }
        return facts;
    }

    private static List<String> matchAll(String text, Pattern pattern) {
        List<String> found = new ArrayList<>();
        Matcher matcher = pattern.matcher(text);
        while (matcher.find()) {
            found.add(matcher.group(1));
        }
        return found;
    }

    private static List<String> strings(JsonNode array) {
        List<String> values = new ArrayList<>();
        array.forEach(node -> values.add(node.asText()));
        return values;
    }

    private static long count(JsonNode array, java.util.function.Predicate<JsonNode> predicate) {
        long total = 0;
        for (JsonNode node : array) {
            if (predicate.test(node)) {
                total++;
            }
        }
        return total;
    }
}
