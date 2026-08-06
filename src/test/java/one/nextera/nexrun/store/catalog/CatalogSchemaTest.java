package one.nextera.nexrun.store.catalog;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SpecVersion;
import com.networknt.schema.ValidationMessage;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Validates {@code catalog/catalog.json} against
 * {@code schemas/catalog-entry.schema.json}.
 *
 * <p>The store enforces no trust of its own — the runtime does the cryptography.
 * What this repository can enforce is that every published record is
 * well formed, so this check runs in {@code mvn test} and not only in CI.
 */
class CatalogSchemaTest {

    private static JsonSchema schema;
    private static JsonNode catalog;

    @BeforeAll
    static void loadSchema() {
        JsonNode schemaNode = StoreFiles.json(StoreFiles.SCHEMA);
        schema = JsonSchemaFactory
                .getInstance(SpecVersion.VersionFlag.V202012)
                .getSchema(schemaNode);
        catalog = StoreFiles.json(StoreFiles.CATALOG);
    }

    @Test
    @DisplayName("catalog.json is a non-empty array of entries")
    void catalogIsNonEmptyArray() {
        assertTrue(catalog.isArray(), "catalog.json must be a JSON array");
        // Guards against the loop below passing vacuously on an empty catalog.
        assertFalse(catalog.isEmpty(), "catalog.json must contain at least one entry");
    }

    @Test
    @DisplayName("every catalog entry validates against the catalog-entry schema")
    void everyEntryMatchesTheSchema() {
        List<String> failures = new ArrayList<>();
        for (int i = 0; i < catalog.size(); i++) {
            JsonNode entry = catalog.get(i);
            Set<ValidationMessage> errors = schema.validate(entry);
            if (!errors.isEmpty()) {
                String slug = entry.path("publisher").asText("?") + "/" + entry.path("slug").asText("?");
                failures.add("entry[" + i + "] (" + slug + "):\n    "
                        + errors.stream()
                        .map(ValidationMessage::getMessage)
                        .sorted()
                        .collect(Collectors.joining("\n    ")));
            }
        }
        assertTrue(failures.isEmpty(),
                () -> "catalog.json violates schemas/catalog-entry.schema.json:\n"
                        + String.join("\n", failures));
    }

    @Test
    @DisplayName("publisher/slug pairs are unique")
    void entryIdentityIsUnique() {
        Set<String> seen = new HashSet<>();
        for (JsonNode entry : catalog) {
            String id = entry.path("publisher").asText() + "/" + entry.path("slug").asText();
            assertTrue(seen.add(id), "duplicate catalog entry: " + id);
        }
    }

    // ---------------------------------------------------------------------
    // Negative cases: the schema must actually reject bad records.
    // A validator that accepts everything is worse than none, because it
    // reads as a guarantee.
    // ---------------------------------------------------------------------

    @ParameterizedTest(name = "source URL rejected: {0}")
    @DisplayName("non-https source URLs are rejected")
    @ValueSource(strings = {
            "javascript:alert(1)",
            "JavaScript:alert(1)",
            "javascript:alert(document.domain)",
            "data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==",
            "http://example.com/insecure",
            "//example.com/protocol-relative",
            "vbscript:msgbox(1)",
            "file:///etc/passwd",
            "https://example.com/\" onmouseover=\"alert(1)",
            "https://example.com/<script>alert(1)</script>",
            "not a url at all"
    })
    void rejectsHostileSourceUrls(String url) {
        ObjectNode entry = validEntry();
        entry.put("source", url);
        assertInvalid(entry, "source", url);
    }

    @ParameterizedTest(name = "documentation URL rejected: {0}")
    @DisplayName("non-https documentation URLs are rejected")
    @ValueSource(strings = {
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "http://example.com/doc"
    })
    void rejectsHostileDocumentationUrls(String url) {
        ObjectNode entry = validEntry();
        entry.put("documentation", url);
        assertInvalid(entry, "documentation", url);
    }

    @Test
    @DisplayName("evidence links must also be https")
    void rejectsHostileEvidenceUrls() {
        ObjectNode entry = validEntry();
        ObjectNode evidence = entry.putObject("evidence");
        evidence.put("sbom", "javascript:alert(1)");
        assertInvalid(entry, "evidence.sbom", "javascript:alert(1)");
    }

    @Test
    @DisplayName("an unknown trust level is rejected")
    void rejectsBogusTrustLevel() {
        ObjectNode entry = validEntry();
        entry.put("trustLevel", "totally-trusted");
        assertInvalid(entry, "trustLevel", "totally-trusted");
    }

    @Test
    @DisplayName("an unknown availability value is rejected")
    void rejectsBogusAvailability() {
        ObjectNode entry = validEntry();
        entry.put("availability", "definitely-shipped");
        assertInvalid(entry, "availability", "definitely-shipped");
    }

    @Test
    @DisplayName("a published entry without release and evidence is rejected")
    void rejectsPublishedWithoutProof() {
        ObjectNode entry = validEntry();
        entry.put("availability", "published");
        assertInvalid(entry, "availability=published", "missing release/evidence");
    }

    @Test
    @DisplayName("a malformed manifest digest is rejected")
    void rejectsMalformedDigest() {
        ObjectNode entry = validEntry();
        entry.put("availability", "published");
        ObjectNode release = entry.putObject("release");
        release.put("version", "1.0.0");
        release.put("reference", "docker.io/library/mysql:8.4");
        release.put("manifestDigest", "sha256:not-a-real-digest");
        release.put("signer", "~nextera");
        entry.putObject("evidence").put("sbom", "https://example.com/sbom.json");
        assertInvalid(entry, "release.manifestDigest", "sha256:not-a-real-digest");
    }

    @Test
    @DisplayName("display text carrying markup is rejected")
    void rejectsMarkupInDisplayText() {
        ObjectNode entry = validEntry();
        entry.put("name", "<img src=x onerror=alert(1)>");
        assertInvalid(entry, "name", "markup");
    }

    @Test
    @DisplayName("an over-long name is rejected (schema maxLength is honoured through $ref)")
    void rejectsOverLongName() {
        ObjectNode entry = validEntry();
        entry.put("name", "n".repeat(81));
        assertInvalid(entry, "name", "81 characters");
    }

    @Test
    @DisplayName("an unknown property is rejected")
    void rejectsUnknownProperty() {
        ObjectNode entry = validEntry();
        entry.put("trustMeBro", true);
        assertInvalid(entry, "trustMeBro", "unknown property");
    }

    @Test
    @DisplayName("an unknown requirements key is rejected")
    void rejectsUnknownRequirementsKey() {
        ObjectNode entry = validEntry();
        ((ObjectNode) entry.get("requirements")).put("processes", 512);
        assertInvalid(entry, "requirements.processes", "unknown key; the canonical name is pids");
    }

    @Test
    @DisplayName("a missing required field is rejected")
    void rejectsMissingRequiredField() {
        ObjectNode entry = validEntry();
        entry.remove("requirements");
        assertInvalid(entry, "requirements", "missing");
    }

    @Test
    @DisplayName("an out-of-range port is rejected")
    void rejectsOutOfRangePort() {
        ObjectNode entry = validEntry();
        ((ObjectNode) entry.get("requirements")).putArray("ports").add(70000);
        assertInvalid(entry, "requirements.ports", "70000");
    }

    @Test
    @DisplayName("an unconstrained NexRun version bound is rejected")
    void rejectsFreeFormVersionBound() {
        ObjectNode entry = validEntry();
        ((ObjectNode) entry.get("requirements")).put("minimumNexRun", ">= anything you like");
        assertInvalid(entry, "requirements.minimumNexRun", ">= anything you like");
    }

    /**
     * Sanity check on the harness itself: the fixture used by every negative
     * case must be valid, otherwise those tests would pass for the wrong reason.
     */
    @Test
    @DisplayName("the negative-test fixture is itself a valid entry")
    void fixtureIsValid() {
        Set<ValidationMessage> errors = schema.validate(validEntry());
        assertEquals(Set.of(), errors, () -> "the test fixture must be valid, but: " + errors);
    }

    private void assertInvalid(JsonNode entry, String field, String value) {
        Set<ValidationMessage> errors = schema.validate(entry);
        assertFalse(errors.isEmpty(),
                () -> "schema accepted a record it must reject — " + field + " = " + value);
    }

    /** A minimal, valid entry used as the base for every negative case. */
    private ObjectNode validEntry() {
        ObjectNode entry = StoreFiles.mapper().createObjectNode();
        entry.put("publisher", "nextera");
        entry.put("slug", "example");
        entry.put("name", "Example");
        entry.put("summary", "A valid fixture entry.");
        entry.put("category", "database");
        entry.put("trustLevel", "official");
        entry.put("availability", "source-kit");
        entry.put("source", "https://example.com/kit");
        entry.putArray("platforms").add("linux");
        entry.putArray("architectures").add("amd64");
        ObjectNode requirements = entry.putObject("requirements");
        requirements.put("runtime", "oci");
        requirements.putArray("ports").add(3306);
        requirements.putArray("volumes").add("example-data");
        requirements.putArray("secrets").add("example-password");
        requirements.putArray("capabilities");
        return entry;
    }
}
