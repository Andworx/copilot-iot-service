# Copilot Studio Agents

This folder contains Copilot Studio agent assets for `AgenticIoT`.

## Structure

```
copilot agents/
└── YOUR_AGENT_NAME/         # One folder per agent
    ├── README.md            # Agent documentation and operating context
    ├── settings.mcs.yml     # Agent-level settings (exported from Copilot Studio)
    └── topics/              # One .mcs.yml file per topic
        ├── Greeting.mcs.yml
        ├── Escalation.mcs.yml
        └── Fallback.mcs.yml
```

## Before You Start

> **Recommended:** Confirm GitHub CLI is installed before beginning — run `gh --version`. Install from <https://cli.github.com> if missing. The workflow may proceed without it, but note the gap.
>
> **Required:** Always invoke the **Copilot Studio Author** agent in GitHub Copilot Chat before making any changes. Open Copilot Chat and select or `@`-mention **Copilot Studio Author** before editing topics, settings, or creating new agents.

See [.github/instructions/copilot-studio-agents.instructions.md](../.github/instructions/copilot-studio-agents.instructions.md) for full conventions and authoring standards.

## Workflow

0. Verify GitHub CLI (`gh --version`) — recommended, not blocking.
1. Invoke the **Copilot Studio Author** agent in GitHub Copilot Chat.
2. Pull latest from Copilot Studio into this folder.
3. Edit topics and settings in source control.
4. Push back to Copilot Studio.
5. Publish the agent.
6. Validate in test chat and embedded portal experience.
