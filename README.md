# NUVA

### A shared vocabulary for understanding vaccines.

Vaccination records use different product names, languages, and coding systems. **NUVA** is a collaborative project that brings vaccines, valences, valence types, and diseases together in a structured nomenclature—giving contributors and developers a common language to describe vaccines and connect vaccination data across systems.

[**Open the admin interface →**](https://admin.nuva.syadem.com/) · [**Explore the full changelog →**](https://syadem.github.io/nuva/)

---

## Shared knowledge, ready to connect

NUVA brings together a collaboratively maintained vocabulary, multilingual content, and structured data designed for integration into software.

The nomenclature is maintained in **YAML**, a popular, easy-to-read format that makes the data straightforward to review and edit.

| | What NUVA offers |
| --- | --- |
| 🤝 **Collaborative by design** | A shared repository for maintaining and improving vaccine knowledge. |
| 🔗 **Connected to external nomenclatures** | Code mappings connect vaccine entries to other nomenclatures, supporting interoperability across systems. |
| ✨ **Approachable administration** | A user-friendly interface connected directly to this GitHub repository. |
| 🌍 **Six languages, with room to grow** | English, French, German, Greek, Latvian, and Polish, with the possibility of adding more. |
| 📖 **A traceable history** | A complete changelog makes it easy to follow the evolution of the nomenclature. |
| 🛠️ **Built for integration** | Structured data connects vaccines, their valences, valence types, and target diseases for use in applications. |

## Contribute through a friendly interface

The [NUVA administration interface](https://admin.nuva.syadem.com/) provides an accessible way to work with the nomenclature, backed by this GitHub repository. It brings a friendly editing experience to a collaborative, version-controlled project.

Want to improve a vaccine entry, suggest a code mapping, or help extend language coverage? Contribute through the admin interface.

## One vocabulary, multiple languages

NUVA supports **English, French, German, Greek, Latvian, and Polish**. Contributors can help complete and improve translations through the admin interface. Additional languages can be added as the project and its community grow, helping the same shared vocabulary serve more people and applications.

## From shared data to your application

NUVA connects vaccine products to generic vaccines. Generic vaccines reference valences, which connect to target diseases and valence types. This shared structure lets applications work with individual vaccine entries and the concepts behind them.

Code mappings to external nomenclatures help connect NUVA entries with the terminology already used in other systems.

### Code mappings

Each nomenclature has a CSV under `codes/<concept>/<nomenclature>.csv`.
The concept folders are `vaccines`, `diseases` and `valences`.
For example, `codes/diseases/syadem.csv` maps disease IDs to Apollon UUIDs.
Every CSV has the header `nuva_id,code,code_label`. The `nuva_id` column refers
to the integer `id` in the corresponding concept YAML. Read `code` as text to
preserve leading zeros. The optional `code_label` column holds the label of the
code in its nomenclature; it is the same on every row of a given code. Fields
follow standard CSV quoting, so labels may contain commas and quotes.

### Translations

English values live in the concept YAML files. The other languages have one CSV
per concept under `translations/<language>/<concept>.csv`, for example
`translations/fr/vaccines.csv`. The concepts are `vaccines`, `diseases`,
`valences` and `valence_types`.
Every CSV starts with `nuva_id` followed by the translated fields: `name` for
all concepts, plus `description` for vaccines. Each entry of the concept has
exactly one row, sorted by `nuva_id`. An empty field is a missing translation. Fields follow
standard CSV quoting and may contain line breaks, but no carriage return nor
leading or trailing whitespace. The data contract is checked by
`spec/translations_spec.rb`.

### Vaccine data structure

Each vaccine is stored in `vaccines/VAC-<id>.yml`, with a positive integer `id`.
The `generic` boolean determines which fields are required:

| Field | Generic vaccine (`generic: true`) | Non-generic vaccine (`generic: false`) |
| --- | --- | --- |
| `valence_ids` | Required array of unique positive integer valence IDs | Must be absent |
| `generic_vaccine_id` | Must be absent | Required positive integer vaccine ID |
| `immunoglobulin` | Required boolean | Must be absent; resolved through the generic vaccine |

Every `valence_ids` entry references an existing `valences/VAL-<id>.yml` file.
The `generic_vaccine_id` references an existing `vaccines/VAC-<id>.yml` file
whose `generic` value is `true`. A vaccine cannot reference itself.
Forbidden fields must be omitted entirely, including when their value would be null
or an empty array.

For example, the relationship fields for a generic vaccine are:

```yaml
id: 345
generic: true
immunoglobulin: false
valence_ids:
- 156
```

A non-generic vaccine referring to it has these relationship fields:

```yaml
id: 1
generic: false
generic_vaccine_id: 345
```

Applications resolve a non-generic vaccine's valences and `immunoglobulin` value
through its generic vaccine.
During import from Apollon, a generic vaccine's `immunoglobulin` is set to `true`
if it or any of its associated non-generic vaccines has a source value of `true`;
it is `false` only when all these source values are `false`.
Disease-to-valence relationships continue to use `valence_ids` directly.
The other vaccine fields and translations follow the same rules for both
vaccine types. The complete data contract is checked by `spec/vaccines_spec.rb`
with `bundle exec rspec`.

### Valence types

Valence types describe the mechanism used to generate the immune response, following
the [NUVA valence types tree](https://nuva.ivci.org/documentation/core/valence_types.html).
Each valence type is stored in `valence_types/VTY-<id>.yml` with an `id`, an optional
`parent_id` referencing another valence type, and an English `name`. The two roots are
`Antigens` and `Antibodies`. Translations live in `translations/<language>/valence_types.csv`.
Each valence references its valence type through `valence_type_id`. It is required for
child valences and optional for root valences, which leave it empty when their children
mix antigens and antibodies. A child valence must have the same valence type as its
parent, or one of its subtypes.

## Follow every change

The nomenclature evolves as contributions are made. Browse the [complete changelog](https://syadem.github.io/nuva/) to explore its history and keep track of updates.
