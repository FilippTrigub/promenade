
# AgentLang Execution Discipline 

This document defines the rules and process I must follow when executing AgentLang programs.

## What is AgentLang?

AgentLang is a declarative, file-centric strategy language that codifies HOW to explore and solve problems. Programs written in AgentLang orchestrate cognitive operations through a small set of verbs, with all state externalized as files (artifacts) under `./component/artifacts/`, where the component is a project component directory in the root directory (usually backend, mobile or frontend). The language describes HOW to think, not WHAT to think.

## Pre-Execution Checklist

Before executing any AgentLang program:
1. Read this discipline file completely.
2. Check execution_state.md for any previous state.
3. Ensure component/artifacts/ directory exists, where the component is a project component directory in the root directory (usually backend, mobile or frontend)

## Execution Rules

### Rule 1: Single-Shot Execution
Each verb execution is atomic. I must:
- Load the verb's intent from the Verb Specifications section below.
- Execute ONLY that cognitive operation.
- Produce exactly one output artifact.
- NOT engage in multi-turn exploration within a single step.

### Rule 2: Artifact Naming
All outputs follow the pattern: `{step_id}_{variable}.{ext}`
- step_id: Monotonic integer (0, 1, 2...).
- variable: The variable name from the program.
- ext: Appropriate extension per verb (see Verb Specifications below).

### Rule 3: Immutability
- Never modify existing artifacts.
- Each step creates a new artifact.
- If revisiting a variable, create a new file with new step_id.

### Rule 4: State Management
After EACH step:
1. Create the artifact in component/artifacts/.
2. Update execution_state.md with:
   - Current step number
   - Variable mapping (variable → artifact path)
   - Status (success/error)
   - Timestamp

### Rule 5: Intent Fidelity
For each verb, I must:
- Follow the Cognitive Goal EXACTLY as specified in Verb Specifications below.
- Meet all Evaluation Hints.
- Use the specified output format.
- Not drift into implementation details when the verb calls for analysis.

## Step-by-Step Execution Process

1. **Parse** - Identify the next statement to execute.
2. **Expand** - If it's a control structure (FOR/WHILE/IF), expand it.
3. **Load** - Get input artifacts based on variable names.
4. **Execute** - Perform the cognitive operation per Verb Specifications.
5. **Validate** - Check output meets evaluation hints.
6. **Save** - Write artifact with correct naming.
7. **Update** - Modify execution_state.md.
8. **Report** - Inform user of completion.

## Advanced Language Concepts

### Functional Composition & Dataflow
Verbs can be nested to form a single, atomic dataflow pipeline. The output of the innermost verb is passed as an anonymous, in-memory artifact to the enclosing verb.
- **Syntax**: `variable = verb1(verb2(verb3(input)))`
- **Execution**: The pipeline is executed from the inside out. Only the final output artifact from the outermost verb (`verb1`) is named and saved to the `component/artifacts/` directory.
- **Example**: `plan = breakdown:tree(evaluate:vote(drafts))` first runs `evaluate:vote`, then immediately feeds the resulting ranking into `breakdown:tree`.

### Artifact Projection for Conditionals
The `IF` and `WHILE` control structures can be driven by the content of artifacts through projection.
- **Syntax**: `variable[json_path]` (e.g., `[pass]`, `[results][0][score]`)
- **Mechanism**: The runtime executes the verb, parses the resulting artifact (e.g., as JSON), and extracts the specified value for use in the boolean condition.
- **Failure Mode**: If projection fails (file not parsable, path does not exist), the condition evaluates to `false` and a warning should be logged.
- **Example**: `WHILE evaluate:test(solution)[pass] == false:`

### IO Verb Namespace
To separate pure cognitive operations from interactions with the external environment, an `io:` namespace is reserved for future use. These verbs may have side effects beyond the `component/artifacts/` directory.
- **Examples**: `io:fetch_url`, `io:exec_shell`, `io:read_file`
- **Discipline**: `io:` verbs must be used cautiously. Their outputs (e.g., web page content, command stdout) must always be captured in a new artifact.

## Verb Specifications

This section contains the complete specification for each verb. Each verb has a fixed cognitive goal that never changes.

### breakdown:parallel
- **Cognitive Goal**: Divergent thinking - generate multiple independent approaches, hypotheses, or sub-plans.
- **Expected Inputs**: 1 artifact (any type).
- **Expected Output**: JSON list of ≥2 items.
- **Default Extension**: `.json`
- **Evaluation Criteria**:
  - Items must be mutually exclusive.
  - Count ≥2 else "FAIL_DIVERGENCE".

### breakdown:tree
- **Cognitive Goal**: Top-down decomposition into a nested outline.
- **Expected Inputs**: 1 artifact.
- **Expected Output**: Markdown outline.
- **Default Extension**: `.md`
- **Evaluation Criteria**:
  - Outline depth ≥2.
  - Leaves collectively cover 100% of original scope.

### breakdown:rootcause
- **Cognitive Goal**: Causal analysis identifying key bottleneck/defect.
- **Expected Inputs**: 1 artifact.
- **Expected Output**: Markdown report with sections: Observation, Cause, Evidence, Next-Steps.
- **Default Extension**: `.md`
- **Evaluation Criteria**:
  - Must cite ≥1 evidence quote from input artifact.
- **Example**:
  - **Statement**: `analysis = breakdown:rootcause(0_test_failure.json)`
  - **Input `0_test_failure.json`**: `{ "pass": false, "error": "AssertionError: Expected 2, got 3" }`
  - **Output `1_analysis.md`**:
    # Root Cause Analysis
    ## Observation
    The test failed with an `AssertionError`. The expected output was 2, but the actual output was 3.
    ## Cause
    The `add_one` function is likely adding two instead of one due to an off-by-one error.
    ## Evidence
    > "AssertionError: Expected 2, got 3"
    ## Next-Steps
    Review the implementation of the `add_one` function and correct the increment logic.

### act:draft
- **Cognitive Goal**: First concrete realization of a plan/idea.
- **Expected Inputs**: Plan artifact (text or JSON).
- **Expected Output**: File with appropriate extension.
- **Default Extension**: Heuristically chosen (`.md`, `.py`, `.sql`, etc.).
- **Evaluation Criteria**:
  - Output compiles/is well-formed (syntax pass).

### act:rewrite
- **Cognitive Goal**: Transform existing artifact while preserving semantics (e.g., refactor, translate, style-fix).
- **Expected Inputs**: 1 artifact.
- **Expected Output**: Same type as input.
- **Default Extension**: Same as input.
- **Evaluation Criteria**:
  - Diff must retain original public interface or summary.

### act:implement
- **Cognitive Goal**: End-to-end production-ready implementation of the chosen design in the app directory.
- **Expected Inputs**: Plan or draft artifact(s).
- **Expected Output**: **FOLDER** containing code, docs, tests, CI config. The value in `execution_state.md` is the path to this directory.
- **Default Extension**: N/A (creates directory).
- **Evaluation Criteria**:
  - `pytest` (if tests present) passes with exit code 0. Failure constitutes a step failure.
  - Lint score ≥8/10 (ruff, flake8 or equivalent).

### evaluate:vote
- **Cognitive Goal**: Rank competing artifacts and justify ordering.
- **Expected Inputs**: ≥2 artifacts of same type.
- **Expected Output**: JSON object with keys `ranking`, `rationale`.
- **Default Extension**: `.json`
- **Evaluation Criteria**:
  - `ranking` list length == inputs count, no duplicates. The list must contain the artifact IDs/paths of the inputs, ordered from best to worst.

### evaluate:test
- **Cognitive Goal**: Run objective benchmark/unit test suite.
- **Expected Inputs**: File or folder containing runnable code.
- **Expected Output**: JSON report `{pass: bool, metrics:{...}}`.
- **Default Extension**: `.json`
- **Evaluation Criteria**:
  - Must include `wall_time_ms`.
  - `pass` true if all tests succeed.

### evaluate:simulate
- **Cognitive Goal**: Predict behavior under hypothetical scenarios.
- **Expected Inputs**: Model or code artifact + scenario description.
- **Expected Output**: JSON of simulation results.
- **Default Extension**: `.json`
- **Evaluation Criteria**:
  - Results must include `assumptions` array.

### select:filter
- **Cognitive Goal**: Deterministically choose artifact(s) based on explicit criteria present in an evaluation file.
- **Expected Inputs**: Exactly one evaluation artifact + the original candidates.
- **Expected Output**: The chosen artifact copied verbatim (same ext/folder).
- **Default Extension**: Same as chosen artifact.
- **Evaluation Criteria**:
  - The chosen artifact's ID must be extracted from the evaluation artifact (e.g., the top item in the `ranking` array).

## Error Handling

If any step fails:
1. Write a structured error to execution_state.md.
2. Create an error artifact: `{step_id}_error.md`.
3. STOP execution.
4. Report the error to the user with context.

The `{step_id}_error.md` artifact must contain:
- **Failed Statement**: The exact line of code that failed.
- **Error Type**: e.g., "VerbExecutionError," "ProjectionFailure."
- **Message**: A human-readable error message from the runtime or LLM.
- **Context**: A snapshot of relevant variable mappings at the time of failure.

## Resumption Protocol

When resuming after pause/error:
1. Read execution_state.md.
2. Identify last successful step.
3. Load all variable mappings.
4. Continue from next statement.

## Appendices

### Appendix A: Quality Checks
Before marking a step complete:
- [ ] Artifact created with correct naming?
- [ ] Output matches verb's expected format?
- [ ] All evaluation hints satisfied?
- [ ] execution_state.md updated?
- [ ] User informed of progress?

### Appendix B: Statement Grammar Reference
- **Basic Statement**: `variable = primitive:version(input1, input2, ...) → .ext  # comment`
- **Control Structures**:
  - **FOR**: `FOR var in [literal1, literal2]: ... END FOR`
  - **WHILE**: `WHILE condition: ... END WHILE`
  - **IF**: `IF condition: ... ELSE: ... END IF`
- **Program Termination**:
  - Programs end with `END PROGRAM`.
  - Programs also terminate after a `select:filter` step.

### Appendix C: Glossary of Terms
- **Artifact**: A single, immutable file in the `component/artifacts/` directory representing a piece of state or a cognitive output.
- **Cognitive Goal**: The specific, fixed intention of a verb.
- **Composition**: Nesting verbs to form a dataflow pipeline within a single statement.
- **Projection**: Extracting a specific value from within an artifact's content for use in a conditional.
- **Atomic Step**: A single statement execution, which is non-interruptible and results in exactly one new named artifact or an error.

### Appendix D: Extensibility Guide
To define a new custom verb, the specification must include:
- **Verb Name**: In `namespace:verb` format.
- **Cognitive Goal**: A clear, one-sentence description of its purpose.
- **Expected Inputs**: Number and type of artifacts.
- **Expected Output**: A description of the output artifact.
- **Default Extension**: The file extension for the output.
- **Evaluation Criteria**: Objective, machine-testable rules the output must follow.
- **Example**: A concrete example of its use.

Remember: AgentLang programs describe HOW to think, not WHAT to think. Focus on faithful execution of the cognitive operations.
