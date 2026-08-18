# Personal Knowledge OS Skill

Version: 1.0

## Skill Identity

```yaml
name: personal-knowledge-os

description:
  AI driven personal knowledge management and skill growth system.

purpose:
  Convert external information into structured knowledge,
  transform knowledge into projects,
  and transform projects into personal capabilities.

core_loop:

  Sources
      ↓
  Knowledge Graph
      ↓
  Projects
      ↓
  Skills

  Build Your Own X:
      Knowledge → Practice → Skill
```

---

# 1. Core Principle

你不是在建立一个笔记库。

你是在建立一个：

> 会持续成长的个人能力操作系统。

核心原则：

```
Information is not knowledge.

Knowledge is not skill.

Skill requires practice.
```

因此：

```
Source
  ↓
Understanding
  ↓
Implementation
  ↓
Experience
  ↓
Capability
```

---

# 2. System Architecture

```
                         AI Agent

                            |

                            ↓


Sources → Knowledge Graph → Projects → Skills

                            ↑

                    Build Your Own X

```

---

# 3. Data Model

系统只维护四类核心对象：

---

# Entity 1: Source

## Definition

外部输入信息。

Examples:

* Books
* Articles
* GitHub repositories
* Papers
* Videos
* Conversations

## Schema

```yaml
Source:

 id:

 title:

 type:

   book
   article
   github
   video
   paper
   conversation


origin:


summary:


extracted_concepts:


questions:


created_at:

```

## Storage

```
/Sources
```

---

# Entity 2: Knowledge

## Definition

用户理解后的知识节点。

Knowledge is:

```
Concept + Relationship + Context
```

## Schema

```yaml
Knowledge:


id:


title:


domain:


type:

  concept
  architecture
  pattern
  principle


summary:


key_points:


related:


depends_on:


source_reference:


practice_reference:


knowledge_level:


0 unknown

1 aware

2 understand

3 implement

4 explain

5 create


```

## Storage

```
/Knowledge
```

---

# Entity 3: Project

## Definition

知识实践过程。

Project exists to answer:

> Can I build this?

## Schema

```yaml
Project:


id:


name:


goal:


type:


  build

  experiment



related_knowledge:


architecture:


implementation:


result:


lessons:


status:


  idea

  building

  completed


```

## Storage

```
/Projects
```

---

# Entity 4: Skill

## Definition

最终能力资产。

Skill requires evidence.

Evidence:

```
Knowledge

+

Project

+

Result
```

## Schema

```yaml
Skill:


id:


name:


domain:


level:


evidence:


projects:


knowledge:


next_improvement:

```

## Storage

```
/Skills
```

---

# 4. AI Agent Definition

AI Agent is responsible for maintaining the flow:

```
Sources

 ↓

Knowledge

 ↓

Projects

 ↓

Skills

```

---

# Agent 1: Capture Agent

## Responsibility

Collect information.

Input:

```
URL
PDF
GitHub
Text
Conversation
```

Output:

```
Source
```

Rules:

* Do not create final knowledge immediately.
* Preserve original information.
* Extract concepts and questions.

---

# Agent 2: Knowledge Architect Agent

## Responsibility

Convert sources into knowledge graph.

Input:

```
Source
```

Output:

```
Knowledge nodes
```

Actions:

* create concepts
* merge duplicates
* create relationships
* update existing knowledge

Rules:

Every knowledge node must have:

```
related:
  at least one
```

---

# Agent 3: Builder Agent

## Responsibility

Convert knowledge into practice.

Trigger:

When:

```
knowledge_level >= 3
```

or:

```
concept is important
```

Create:

```
Project
```

Example:

Input:

```
Learn Redis Architecture
```

Output:

```
Project:

Build My Redis

Tasks:

- implement protocol
- implement storage
- implement event loop
- benchmark
```

---

# Agent 4: Skill Evaluator Agent

## Responsibility

Convert completed projects into skills.

Evaluate:

```
Knowledge

+

Implementation

+

Experience
```

Skill levels:

```
Level 0
Unknown


Level 1
Understand


Level 2
Apply


Level 3
Implement


Level 4
Optimize


Level 5
Create
```

---

# 5. Build Your Own X Engine

## Purpose

The engine that converts knowledge into capability.

Rule:

```
Important Knowledge

        ↓

Build Something

        ↓

Encounter Problems

        ↓

Deep Understanding

        ↓

Skill
```

---

# Build Project Template

```markdown

# Project Name


## Goal


## Related Knowledge


## Architecture


## Implementation


## Experiment


## Result


## Lessons Learned


## New Skills


```

---

# 6. Folder Structure

Recommended:

```
SecondBrain/


├── Sources/

├── Knowledge/

├── Projects/

├── Skills/


├── Inbox/

├── Experiments/

└── Memory/

```

---

# 7. Operating Workflow

## Daily

AI Agent:

1. Collect new information

2. Update Sources

3. Detect knowledge candidates

4. Suggest next action

---

## Weekly

AI Agent:

Generate:

```
Knowledge Update Report

```

Including:

* New knowledge nodes
* New relationships
* Project progress
* Skill growth

---

## Monthly

Generate:

```
Personal Capability Report

```

Including:

* strongest skills
* weak areas
* recommended projects
* learning roadmap

---

# 8. Automation Rules

## Rule 1

Never store isolated information.

Bad:

```
Redis.md
```

Good:

```
Redis

related:

- Event Loop
- Linux IO
- Database Design

```

---

## Rule 2

Important knowledge must produce projects.

```
Knowledge

↓

Project

```

---

## Rule 3

Projects must create reflection.

Every completed project requires:

```
Lessons Learned

New Knowledge

Skill Update

```

---

## Rule 4

Skills require evidence.

No evidence:

```
No skill
```

Evidence:

```
Implemented

Measured

Explained

Improved

```

---

# 9. Final Output

The system should continuously produce:

```
Sources

↓

Knowledge Graph

↓

Projects

↓

Skills

↓

Expertise

```

Final objective:

Build an AI assisted personal operating system
that continuously converts information into expertise.

```

---

# End of Skill
```
