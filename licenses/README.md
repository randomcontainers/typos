# Extra license files

Five crates that typos is built from publish no license text, or only a file that names texts the crate leaves out. Each `crates/<crate>-<version>/` directory here holds those texts, and `scripts/cargo-licenses.py` adds them to the crate's own files in the image. The build stops when the binary records a crate without any license file, and when it records another version of a crate that has a directory here, so that the text is checked again before the directory is renamed. A directory named without a version, `crates/<crate>/`, is kept across versions instead; it needs an `EXPRESSION` file with the crate's license expression, and the build stops when the crate's expression changes.

| Files | Source |
|---|---|
| `crates/difflib-0.4.0/LICENSE` | `LICENSE` of [DimaKudosh/difflib](https://github.com/DimaKudosh/difflib), unchanged since it was added for 0.3.0 |
| `crates/Inflector-0.11.4/LICENSE.md` | `LICENSE.md` of [whatisinternet/Inflector](https://github.com/whatisinternet/Inflector), unchanged since 2017 |
| `crates/schemafy_core-0.6.0/LICENSE`, `crates/schemafy_lib-0.6.0/LICENSE` | `LICENSE` of [Marwes/schemafy](https://github.com/Marwes/schemafy) at v0.6.0 |
| `crates/siphasher-1.0.1/LICENSE-MIT`, `crates/siphasher-1.0.1/LICENSE-APACHE` | the texts that siphasher 1.0.1's `COPYING` names, from [jedisct1/rust-siphash](https://github.com/jedisct1/rust-siphash), where they were added in commit 07a910ae and first released in 1.0.4 |
| `misspell/LICENSE` | `LICENSE` of [client9/misspell](https://github.com/client9/misspell) |
| `codespell/CC-BY-SA-3.0` | the legal code of [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/legalcode.txt) |
| `wikipedia/CC-BY-SA-4.0` | the legal code of [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/legalcode.txt) |
| `codespell/NOTICE`, `wikipedia/NOTICE`, `varcon/NOTICE` | written for this repository: where the entries of typos's word lists came from, and that the VarCon data in the binary is modified |
