git-issue
====================================================

git subcommand of browse/modify issue traker's tickets.

now supporse Redmine,Github-issues

## ScreenShots

<img src='https://github.com/yuroyoro/git-issue/raw/master/images/git-issue_screenshot-1.png' width='600'/>
<img src='https://github.com/yuroyoro/git-issue/raw/master/images/git-issue_screenshot-2.png' width='600'/>

## Instration

    $ gem install git-issue

    or

    $ git clone https://github.com/yuroyoro/git-issue.git
    $ cd git-issue
    $ gem install jeweler
    $ rake install

## Configuration

set type of issue traking system(redmine or github)

    $ git config issue.type redmine

set url of issue traking system's api endopoint.

    $ git config issue.url http://redmine.example.com

set api-key for accessing issue traking system.

    $ git config issue.apikey FWeaj3I9laei03A....

set repository name if using github.

    $ git config issue.repo gitterb

set your account name if using github.

    $ git config issue.user yuroyoro

## Usage(Redmine)

    git issue <command> [ticket_id] [<args>]

    Commnads:
      show     s show given issue summary. if given no id,  geuss id from current branch name.
      list     l listing issues.
      mine     m display issues that assigned to you.
      commit   c commit with filling issue subject to messsage.if given no id, geuss id from current branch name.
      update   u update issue properties. if given no id, geuss id from current branch name.
      branch   b checout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)
      publish  pub push branch to remote repository and set upstream
      rebase   rb rebase branch onto specific newbase
      help     h show usage.
      local    loc listing local branches tickets
      project  prj listing ticket belongs to sspecified project

    Options:
      -a, --all                        update all paths in the index file
      -f, --force                      force create branch
      -v, --verbose                    show issue details
      -n, --max-count=VALUE            maximum number of issues
          --oneline                    display short info
          --raw-id                     output ticket number only
          --remote=VALUE               on publish, remote repository to push branch
          --onto=VALUE                 on rebase, start new branch with HEAD equal to "newbase"
          --debug                      debug print
      -j, --supperss_journals          show issue journals
      -r, --supperss_relations         show issue relations tickets
      -c, --supperss_changesets        show issue changesets
      -q, --query=VALUE                filter query of listing tickets
          --subject=VALUE              use the given value to update subject
          --ratio=VALUE                use the given value to update done-ratio(%)
          --status=VALUE               use the given value to update issue statues id
          --priority=VALUE             use the given value to update issue priority id
          --tracker=VALUE              use the given value to update tracker id
          --assigned_to_id=VALUE       use the given value to update assigned_to id
          --category=VALUE             use the given value to update category id
          --fixed_version=VALUE        use the given value to update fixed_version id
          --custom_fields=VALUE        value should be specifies '<custom_fields_id1>:<value2>,<custom_fields_id2>:<value2>, ...'
          --notes=VALUE                add notes to issue

## Usage(Github Issues)

    git issue <command> [ticket_id] [<args>]

    Commnads:
      show     s show given issue summary. if given no id,  geuss id from current branch name.
      list     l listing issues.
      mine     m display issues that assigned to you.
      commit   c commit with filling issue subject to messsage.if given no id, geuss id from current branch name.
      add      a create issue.
      update   u update issue properties. if given no id, geuss id from current branch name.
      branch   b checout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)
      publish  pub push branch to remote repository and set upstream
      rebase   rb rebase branch onto specific newbase
      help     h show usage.
      mention  men create a comment to given issue

    Options:
      -a, --all                        update all paths in the index file
      -f, --force                      force create branch
      -v, --verbose                    show issue details
      -n, --max-count=VALUE            maximum number of issues
          --oneline                    display short info
          --raw-id                     output ticket number only
          --remote=VALUE               on publish, remote repository to push branch
          --onto=VALUE                 on rebase, start new branch with HEAD equal to "newbase"
          --debug                      debug print
      -s, --supperss_commentsc         show issue journals
          --title=VALUE                Title of issue.Use the given value to create/update issue.
          --body=VALUE                 Body content of issue.Use the given value to create/update issue.
          --state=VALUE                Use the given value to create/update issue. or query of listing issues.Where 'state' is either 'open' or 'closed'
          --milestone=VALUE            Use the given value to create/update issue. or query of listing issues, (Integer Milestone number)
          --assignee=VALUE             Use the given value to create/update issue. or query of listing issues, (String User login)
          --mentioned=VALUE            Query of listing issues, (String User login)
          --labels=VALUE               Use the given value to create/update issue. or query of listing issues, (String list of comma separated Label names)
          --sort=VALUE                 Query of listing issues, (created,  updated,  comments,  default: created)
          --direction=VALUE            Query of listing issues, (asc or desc,  default: desc.)
          --since=VALUE                Query of listing issue, (Optional string of a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ)
          --password=VALUE             For Authorizaion of create/update issue.  Github API v3 does'nt supports API token base authorization for now. then, use Basic Authorizaion instead token.

## Copyright

Copyright (c) 2011 Tomohito Ozaki. See LICENSE for details.
