# Instances

## What is an instance?

An Instance is an autonomous OpenLoop runner that lives on your machine. It's a background worker that runs your workflows on schedule.

You set it up once. It keeps working. Forever.
You then watch the results and tweak prompts to better suit your needs.

## How it works

Each instance watches a folder containing your personas and workflows. When a workflow's schedule fires—the instance wakes up and runs that workflow.

[Workflows](workflow) represent processes in a company.
[Personas](persona) represent opinionated employees each performing its role.

Think how your company works and encode it into a set of structured workflows.

An instance is your always-on simulation. Set it up, run experiments, iterate, and let the workflow teach you what works. Go do something else while your organizational sandbox runs itself.

## The folder-watching magic

Instances are tied to folders. This means:
- Different projects have different instances
- Each instance can define its own set of [personas](persona) and [workflows](workflow)
- You can spin up an instance for a specific project and shut it down when done
