git-issue
====================================================

git subcommand of browse/modify issue traker's tickets.

now available issue-tracker system is Redmine and Github-issues.

## ScreenShots

<img src='https://github.com/yuroyoro/git-issue/raw/master/images/git-issue_screenshot-1.png' width='600'/>
<img src='https://github.com/yuroyoro/git-issue/raw/master/images/git-issue_screenshot-2.png' width='600'/>

## Installation

    $ gem install git-issue

    or

    $ git clone https://github.com/yuroyoro/git-issue.git
    $ cd git-issue
    $ gem install jeweler
    $ rake install

## Configuration(Redmine)

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

## Configuration(Github Issues)

set type of issue traking system(redmine or github)

    $ git config issue.type github

set user and password of github(for authentication)

    $ EDITOR=vim pit set github

## Usage(Redmine)

    git issue <command> [ticket_id] [<args>]

    Commnads:
      show     s show given issue summary. if given no id,  geuss id from current branch name.
      view     v view issue in browser. if given no id,  geuss id from current branch name.
      list     l listing issues.
      mine     m display issues that assigned to you.
      commit   c commit with filling issue subject to messsage.if given no id, geuss id from current branch name.
      add      a create issue.
      update   u update issue properties. if given no id, geuss id from current branch name.
      branch   b checkout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)
      publish  pub push branch to remote repository and set upstream
      rebase   rb rebase branch onto specific newbase
      help     h show usage.
      local    loc listing local branches tickets
      project  pj listing ticket belongs to sspecified project

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
      -j, --supperss_journals          do not show issue journals
      -r, --supperss_relations         do not show issue relations tickets
      -c, --supperss_changesets        do not show issue changesets
      -q, --query=VALUE                filter query of listing tickets
          --project_id=VALUE           use the given value to create subject
          --description=VALUE          use the given value to create subject
          --subject=VALUE              use the given value to create/update subject
          --ratio=VALUE                use the given value to create/update done-ratio(%)
          --status=VALUE               use the given value to create/update issue statues id
          --priority=VALUE             use the given value to create/update issue priority id
          --tracker=VALUE              use the given value to create/update tracker id
          --assigned_to_id=VALUE       use the given value to create/update assigned_to id
          --category=VALUE             use the given value to create/update category id
          --fixed_version=VALUE        use the given value to create/update fixed_version id
          --custom_fields=VALUE        value should be specifies '<custom_fields_id1>:<value2>,<custom_fields_id2>:<value2>, ...'
          --notes=VALUE                add notes to issue

## Usage(Github Issues)

    git issue <command> [ticket_id] [<args>]

    Commnads:
      show     s show given issue summary. if given no id,  geuss id from current branch name.
      view     v view issue in browser. if given no id,  geuss id from current branch name.
      list     l listing issues.
      mine     m display issues that assigned to you.
      commit   c commit with filling issue subject to messsage.if given no id, geuss id from current branch name.
      add      a create issue.
      update   u update issue properties. if given no id, geuss id from current branch name.
      branch   b checkout to branch using specified issue id. if branch dose'nt exisits, create it. (ex ticket/id/<issue_id>)
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
          --password=VALUE             For Authorizaion of create/update issue.  Github API v3 doesn't supports API token base authorization for now. then, use Basic Authorizaion instead token.
          --sslnoverify                don't verify SSL

## Copyright

Copyright (c) 2011 Tomohito Ozaki. See LICENSE for details.
