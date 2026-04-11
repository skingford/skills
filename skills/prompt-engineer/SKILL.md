---
name: prompt-engineer
description: "Prompt engineering methodology for LLM applications. Use when crafting system prompts, designing few-shot examples, building chain-of-thought reasoning, or evaluating prompt quality. Triggers on tasks involving prompt writing, LLM integration, AI application development, or prompt optimization."
---

# Prompt Engineer

Structured methodology for writing effective, maintainable prompts for LLM applications.

## When to Use

Use this skill when:

- Writing or refining system prompts for AI applications
- Designing few-shot examples or chain-of-thought patterns
- Building prompt templates with variable injection
- Evaluating or debugging prompt quality
- Integrating LLMs into applications

Do NOT use this skill when:

- Having a casual conversation with an LLM
- Working on non-AI-related code

## System Prompt Structure

Follow this ordering for system prompts:

```
1. Role & Identity    — Who the model is
2. Context            — Background knowledge the model needs
3. Instructions       — What to do (core task)
4. Constraints        — What NOT to do (guardrails)
5. Output Format      — How to structure the response
6. Examples           — Few-shot demonstrations (if needed)
```

```
// Good — clear structure
You are a code review assistant for a Python backend team.

## Context
The codebase uses FastAPI, SQLAlchemy, and follows PEP 8.

## Instructions
Review the provided code diff and identify:
- Security vulnerabilities
- Performance issues
- Style violations

## Constraints
- Do not suggest refactoring beyond the diff scope
- Do not comment on test files unless security-relevant

## Output Format
For each issue found:
- **File**: filename
- **Line**: line number
- **Severity**: critical / warning / info
- **Issue**: description
- **Fix**: suggested change
```

## Prompt Writing Principles

### Be Specific, Not Vague

```
Bad:  "Analyze this code"
Good: "Identify SQL injection vulnerabilities in this Python code.
       For each vulnerability, show the affected line and a parameterized
       query fix."
```

### Use Positive Instructions

```
Bad:  "Don't write long responses"
Good: "Respond in 3 bullet points, each under 20 words"
```

### Provide Structure, Not Freedom

```
Bad:  "Format the output however you think is best"
Good: "Return a JSON object with keys: summary (string), issues (array),
       severity (enum: low/medium/high)"
```

### Ground with Examples

```
Bad:  "Classify the sentiment"
Good: "Classify the sentiment as positive, negative, or neutral.

       Examples:
       Input: 'This product exceeded my expectations!'
       Output: positive

       Input: 'Shipping was slow but the item works fine.'
       Output: neutral"
```

## Few-Shot Design

- Use 3-5 examples that cover the range of expected inputs
- Include at least one edge case or boundary example
- Keep examples consistent in format and length
- Order from simple to complex
- Label examples clearly: `Input:` / `Output:` or `User:` / `Assistant:`

```
## Examples

### Example 1: Simple extraction
Input: "Call me at 555-0123 or email john@example.com"
Output: {"phone": "555-0123", "email": "john@example.com"}

### Example 2: Missing fields
Input: "My name is Alice"
Output: {"phone": null, "email": null}

### Example 3: Multiple values
Input: "Reach me at alice@a.com or bob@b.com"
Output: {"phone": null, "email": ["alice@a.com", "bob@b.com"]}
```

## Chain-of-Thought (CoT)

Use CoT when the task requires reasoning, math, or multi-step logic.

```
// Explicit CoT instruction
Think through this step by step:
1. Identify the relevant code paths
2. Trace the data flow from input to output
3. Check each path for potential null references
4. Report your findings

// Structured CoT with XML tags
<thinking>
[Work through the problem here]
</thinking>

<answer>
[Final answer here]
</answer>
```

- Use CoT for reasoning-heavy tasks (analysis, debugging, planning)
- Skip CoT for extraction, classification, or formatting tasks
- Use XML tags (`<thinking>`, `<answer>`) to separate reasoning from output

## Prompt Templates

Use clear delimiters for variable injection:

```
Review the following {{language}} code for {{review_type}} issues:

```{{language}}
{{code}}
```

Focus areas: {{focus_areas}}
```

- Use `{{variable}}` or `{variable}` for template placeholders
- Document all variables with types and examples
- Validate inputs before injection to prevent prompt injection
- Escape user content when embedding in prompts

## Prompt Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Wall of text | Model loses focus | Break into labeled sections |
| Contradictory rules | Unpredictable behavior | Resolve conflicts, prioritize |
| Too many examples | Context window waste | 3-5 diverse examples |
| Vague output format | Inconsistent responses | Specify exact schema |
| No edge case handling | Failures on unusual input | Add "if X then Y" rules |
| Over-constraining | Reduces quality | Focus on critical constraints only |

## Evaluation

When testing prompts:

1. **Golden set**: Maintain 10-20 representative input/output pairs
2. **Edge cases**: Test with empty input, very long input, adversarial input
3. **Consistency**: Run the same prompt 5x — outputs should be consistent
4. **A/B compare**: When iterating, compare old vs new on the same inputs
5. **Failure modes**: Document known failure cases and mitigations

## Recommended Scope

- **Scope**: Global (useful across all AI-related projects)
- **Install**: `npx skills add skingford/skills --skill prompt-engineer -g -y`
