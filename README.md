# Beginner-Friendly Semgrep Source Code Review Rules

A learning-oriented Semgrep rules collection for reviewing application source code for common security weaknesses, risky coding patterns, sensitive-data exposure, and code-hygiene issues.

> **Important:** This is a starter ruleset, not a complete security product. The custom rules originated as an unvalidated draft. Validate them with your installed Semgrep version, test them against vulnerable and safe examples, and tune false positives before relying on them. A Semgrep match is an investigation lead—not proof that a vulnerability is exploitable. A clean scan does not prove that code is secure.

## What is included?

| File | What it looks for |
|---|---|
| `01-hardcoded-secrets.yaml` | Possible API keys, tokens, private keys, credentials, and credential-bearing connection strings |
| `02-hardcoded-elements.yaml` | Hardcoded IPs, URLs, internal hostnames, emails, privileged usernames, ports, and crypto material |
| `03-information-disclosure.yaml` | Debug settings, stack traces, sensitive logging, verbose errors, wildcard CORS, and debug artifacts |
| `04-sensitive-data.yaml` | Possible PAN/Aadhaar/SSN/card data, PII field names, credentials in URLs, and sensitive browser storage |
| `05-injection-taint.yaml` | Selected source-to-sink patterns for SQL injection, command injection, path traversal, SSRF, XSS, and redirects |
| `06-misconfig-crypto-auth.yaml` | Weak hashes/randomness, TLS verification disabled, JWT verification issues, cookie/CSRF settings, unsafe deserialization, XXE, and related patterns |
| `07-code-hygiene.yaml` | Debug statements, TODO/FIXME markers, swallowed exceptions, constant branches, and heuristic code-quality checks |

The initial custom rules cover selected patterns in Python, JavaScript/TypeScript, Java, PHP, and Go, plus generic text/regex checks. Actual language coverage varies by rule. They do not replace a full manual review, framework-specific testing, dependency scanning, or runtime testing.

## 1. Requirements

- Python 3.10+ is recommended for installing the Semgrep CLI using `pipx`.
- Git.
- Internet access for Semgrep Registry rules (the custom YAML rules can be run locally).

## 2. Install Semgrep on Kali Linux

Recommended isolated installation with `pipx`:

```bash
sudo apt update
sudo apt install -y pipx
pipx ensurepath
```

Close and reopen the terminal, then run:

```bash
pipx install semgrep
semgrep --version
```

If `pipx` is already installed, skip the apt command. Avoid installing packages into Kali's system-managed Python environment with `sudo pip`.

## 3. Get the rules

Clone this repository:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/semgrep-source-review.git
cd semgrep-source-review
```

Replace `YOUR_GITHUB_USERNAME` with your GitHub username.

## 4. Validate the custom rules before scanning

Run validation separately for every rule file:

```bash
for rule in semgrep-rules/*.yaml; do
  echo "Validating: $rule"
  semgrep --validate --config "$rule" || break
done
```

If a file fails validation, do not ignore the error. Read the reported line, correct the YAML or Semgrep rule syntax, and validate it again. Rule syntax and supported features can differ across Semgrep versions.

Validation checks whether Semgrep can parse the rules. It does **not** prove that a rule detects the intended bug correctly or avoids false positives.

## 5. Run your first scan

Start with the custom rules only:

```bash
./semgrep-rules/run-all.sh --custom-only /path/to/your/source-code
```

Example:

```bash
./semgrep-rules/run-all.sh --custom-only ~/projects/my-api
```

To scan the current directory:

```bash
./semgrep-rules/run-all.sh --custom-only .
```

The runner writes SARIF reports to `semgrep-results/` in this repository. The output directory is ignored by Git because reports can contain source snippets and internal paths.

### Run the broader Registry rules too

After your first custom-only run, try:

```bash
./semgrep-rules/run-all.sh --with-registry /path/to/your/source-code
```

This also requests Semgrep Registry packs: `p/default`, `p/security-audit`, `p/owasp-top-ten`, `p/cwe-top-25`, and `p/secrets`. Registry configurations require network access and may change over time. If a pack cannot be resolved, check the current Semgrep Registry documentation and remove or replace that pack.

## 6. Understand a finding

For each result, record:

1. **Rule ID** — which check matched.
2. **File and line** — where Semgrep found the pattern.
3. **Matched code** — what exact expression or text triggered it.
4. **Source** — where the input/value originates (for taint findings).
5. **Sink** — where the value is used (for taint findings).
6. **Controls** — validation, encoding, parameterization, authorization, or other protections nearby.
7. **Impact** — what an attacker could realistically achieve.
8. **Evidence** — code path, test, or reproduction that supports your conclusion.

### Beginner example: SQL injection

Vulnerable pattern:

```python
user_id = request.args.get("id")
query = "SELECT * FROM users WHERE id = " + user_id
cursor.execute(query)
```

Why investigate it: data controlled by a web request appears to flow into a SQL statement. If it reaches the database as SQL syntax, an attacker may alter the query.

Safer approach (parameter syntax depends on the database driver):

```python
user_id = request.args.get("id")
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

The parameterized query keeps the value separate from the SQL statement. Confirm the placeholder syntax for the specific database library.

### Beginner example: command injection

Risky:

```python
import os
host = request.args.get("host")
os.system("ping -c 1 " + host)
```

Prefer avoiding shell execution. If a system command is genuinely required, use a fixed executable, an argument list, strict input validation, and `shell=False`:

```python
import subprocess

host = request.args.get("host", "")
subprocess.run(
    ["/usr/bin/ping", "-c", "1", host],
    check=False,
    shell=False,
)
```

This is an illustration, not a complete input-validation policy. Validate that `host` is an allowed hostname or IP address before use.

## 7. Triage results: true positive, false positive, or needs review

Do not automatically call every match a vulnerability.

- **True positive:** the risky behavior exists in a reachable code path and the required protections are absent or insufficient.
- **False positive:** the pattern matched, but context shows the behavior is safe or irrelevant.
- **Needs review:** the available code does not establish exploitability or safety.

For each finding, document the reason. If suppressing a match, use a narrow, justified `nosemgrep` comment where supported, and explain why it is safe. Do not suppress a whole rule just to make the scan green.

## 8. Recommended beginner workflow

1. Scan a small, authorized training application or your own repository.
2. Validate all seven custom YAML files.
3. Run custom rules first; then run Registry packs.
4. Start with `ERROR` findings, then `WARNING`, then `INFO`.
5. Open each result in the source code and trace the input to its use.
6. Verify whether validation, encoding, parameterized APIs, or access controls change the risk.
7. Write a short finding with title, affected file/line, evidence, impact, and remediation.
8. Fix one issue and rerun the same scan to confirm the result changed as expected.
9. Add regression tests for the fixed behavior.
10. Tune rules only after you have a reproducible example.

## 9. Validate rule quality with test cases

For every custom rule you intend to rely on, create at least:
- one intentionally vulnerable example that should match;
- one safe example that should not match;
- one edge case that may be ambiguous.

Use Semgrep's rule testing workflow (`semgrep --test`) with rule test fixtures and `ruleid` / `ok` annotations. See the official Semgrep rule-writing and testing documentation before treating a custom rule as production-ready.

## 10. GitHub Actions

The included workflow at `.github/workflows/semgrep.yml` runs on pushes, pull requests, and manual dispatches. It installs Semgrep and scans the repository with `p/default` plus the seven local rule files.

The workflow is a starter CI check. Review its logs after the first push. If you want the workflow to fail a pull request when findings exist, deliberately add an appropriate failure policy after assessing the baseline; do not enable blocking blindly on an unvalidated ruleset.

## 11. Limitations to understand

- Semgrep is static analysis. It does not execute the application or prove exploitability.
- Community/local analysis may not follow every data flow across files and functions. Complex applications may need deeper analysis and manual tracing.
- The custom taint rules define only selected sources and sinks. They will miss frameworks, APIs, wrappers, and flows not represented in the rules.
- Regex-based checks can match examples, tests, documentation, and harmless values.
- The Aadhaar, PAN, SSN, card-number, IP, URL, and email checks are pattern-based and can produce false positives. Do not copy real personal data into public test fixtures.
- The `py-unused-assignment-heuristic` rule is explicitly heuristic. Use a language-specific linter for reliable unused-variable checks.
- The `js-x-powered-by` and `missing-security-headers-hint` checks are hints, not proof that a security header is missing.
- No scanner replaces threat modeling, authorization review, secure design review, manual code review, or dynamic testing.

## 12. Responsible use

Run this tool only against source code you own or are explicitly authorized to review. Do not commit API keys, credentials, private keys, customer data, production logs, or unredacted scan reports to this public repository.

## References

- [Semgrep documentation](https://semgrep.dev/docs/)
- [Semgrep CLI and rule packs](https://semgrep.dev/docs/cli-reference/)
- [Semgrep rule syntax](https://semgrep.dev/docs/writing-rules/overview/)
- [Semgrep rule testing](https://semgrep.dev/docs/writing-rules/testing-rules/)
- [Semgrep Registry](https://semgrep.dev/explore)

---

**Status:** Learning/starter project. Custom rules require validation and test coverage before production use.
