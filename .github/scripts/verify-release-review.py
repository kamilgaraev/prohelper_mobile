import json
import os
import re
import subprocess
import sys


def pages(endpoint, *args):
    result = subprocess.run(
        ["gh", "api", endpoint, "--paginate", "--slurp", *args],
        check=True, stdout=subprocess.PIPE, encoding="utf-8",
    )
    return json.loads(result.stdout)


def verify(repo, sha):
    if not re.fullmatch(r"[a-f0-9]{40}", sha):
        raise ValueError("Требуется полный SHA коммита")
    prs = [pr for page in pages(f"repos/{repo}/commits/{sha}/pulls?per_page=100")
           for pr in page if pr["merged_at"] and pr["base"]["ref"] == "main"
           and pr["base"]["repo"]["full_name"] == repo and pr["merge_commit_sha"] == sha]
    if len(prs) != 1:
        raise ValueError("Для ревизии нужен один squash PR, слитый в main")
    pr = prs[0]
    number, head = pr["number"], pr["head"]["sha"]
    if not isinstance(head, str) or not re.fullmatch(r"[a-f0-9]{40}", head):
        raise ValueError(f"Недействительный head SHA в PR #{number}")
    verify_head(repo, number, head)
    print(f"PR #{number}, Codex Review {head}, release {sha}")


def verify_head(repo, number, head):
    reports = []
    for page in pages(f"repos/{repo}/issues/{number}/comments?per_page=100"):
        for comment in page:
            if (comment["user"]["id"] != 199175422 or
                    (comment.get("performed_via_github_app") or {}).get("slug") != "chatgpt-codex-connector"):
                continue
            match = re.search(r"^<!-- codex-review-state:v1 (.+) -->\s*$", comment["body"], re.M)
            if match:
                reports.append(json.loads(match[1])["code_review"])
    if len(reports) != 1 or reports[0].get("commit_sha") != head or reports[0].get("status") != "completed" or reports[0].get("has_unresolved_findings") is not False:
        raise ValueError(f"Нет завершённого Codex Review для PR #{number}, {head}")
    owner, name = repo.split("/")
    query = """query($owner:String!, $name:String!, $number:Int!, $endCursor:String) {
      repository(owner:$owner, name:$name) { pullRequest(number:$number) {
        reviewThreads(first:100, after:$endCursor) {
          nodes { isResolved } pageInfo { hasNextPage endCursor }
        }
      } }
    }"""
    threads = pages("graphql", "-f", f"query={query}", "-f", f"owner={owner}",
                    "-f", f"name={name}", "-F", f"number={number}")
    if not threads or any(not node["isResolved"] for page in threads
                          for node in page["data"]["repository"]["pullRequest"]["reviewThreads"]["nodes"]):
        raise ValueError(f"Проверьте обсуждения PR #{number}")
    runs = [run for page in pages(f"repos/{repo}/actions/workflows/pr-checks.yml/runs"
                                  f"?head_sha={head}&event=pull_request&per_page=100")
            for run in page["workflow_runs"] if run["head_sha"] == head
            and run["path"] == ".github/workflows/pr-checks.yml"
            and any(pr["number"] == number for pr in run["pull_requests"])]
    latest = max(runs, key=lambda run: run["id"], default=None)
    if not latest or latest["status"] != "completed" or latest["conclusion"] != "success":
        raise ValueError(f"Нет успешной проверки PR #{number} для {head}")


def publish_status(repo, number):
    if not re.fullmatch(r"[1-9][0-9]*", number):
        raise ValueError("Некорректный номер PR")
    pr = pages(f"repos/{repo}/pulls/{number}")[0]
    if pr["state"] != "open" or pr["base"]["ref"] != "main":
        return
    head = pr["head"]["sha"]
    if not re.fullmatch(r"[a-f0-9]{40}", head):
        raise ValueError("Недействительный SHA открытого PR")
    endpoint = f"repos/{repo}/statuses/{head}"
    status = ["gh", "api", endpoint, "-f", "context=most/release-admission"]
    subprocess.run([*status, "-f", "state=pending"], check=True)
    try:
        verify_head(repo, int(number), head)
    except (ValueError, KeyError, TypeError, subprocess.CalledProcessError):
        subprocess.run([*status, "-f", "state=failure"], check=True)
        raise
    subprocess.run([*status, "-f", "state=success"], check=True)


if __name__ == "__main__":
    repository = os.environ["GITHUB_REPOSITORY"]
    if sys.argv[1] == "--status":
        publish_status(repository, sys.argv[2])
    else:
        verify(repository, sys.argv[1])
