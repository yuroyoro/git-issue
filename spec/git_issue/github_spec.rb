require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GitIssue::Github do

  let(:apikey) { "ABCDEFG1234567890" }
  let(:user)   { "yuroyoro" }
  let(:repo)   { "gitterb" }

  describe '#initialize' do
    context 'ginve no apikey ' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Github.new(args) }.should raise_error }
    end

    context 'given no user' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Github.new(args, :apikey => apikey) }.should raise_error }
    end

    context 'given no repo' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Github.new(args, :apikey => apikey, :user => user) }.should raise_error }
    end

    context 'given apikey, user and repo ' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Github.new(args, :apikey => apikey, :user => user, :repo => repo) }.should_not raise_error }
    end
  end

  describe '#show' do
    let(:args) { ["show", "1234"] }
    let(:sysout) { StringIO.new }
    let(:syserr) { StringIO.new }
    let(:github) { GitIssue::Github.new(args, :apikey => apikey, :user => user, :repo => repo,  :sysout => sysout, :syserr => syserr) }

    let(:json) {{"issue"=>
        {"body"       =>"change diff views like github.",
         "closed_at"  =>"2011/07/20 01:48:05 -0700",
         "comments"   =>1,
         "created_at" =>"2011/07/14 04:14:12 -0700",
         "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
         "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/1",
         "labels"     =>[],
         "number"     =>1,
         "position"   =>1.0,
         "state"      =>"closed",
         "title"      =>"improve diff views",
         "updated_at" =>"2011/07/20 01:48:05 -0700",
         "user"       =>"yuroyoro",
         "votes"      =>0}}
    }

    let(:comments) { [
        { "user"=>"yuroyoro",  "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
          "updated_at"=>"2011/07/20 01:48:05 -0700",  "body"=>"completed.",  "id"=>1613903,
          "created_at"=>"2011/07/20 01:48:05 -0700"},
        { "user"=>"foolesa",  "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
          "updated_at"=>"2011/07/22 03:50:05 -0700",
          "body"=>"らめぇぁ…あ！！！あひゃぴー?ひぃぱぎぃっうふふ?",  "id"=>1613904,
          "created_at"=>"2011/07/23 04:48:05 -0700"}
      ]
    }

    context 'given no ticket_id' do
      it { lambda {github.show() }.should raise_error( 'ticket_id is required.') }
    end

    context 'given ticket_id' do

      before {
        github.should_receive(:fetch_json).and_return(json)
        github.show(:ticket_id => 1234)
      }
      subject { github.sysout.rewind; github.sysout.read }

      it { sysout.length.should_not be_zero }
      it { syserr.length.should be_zero }

      it { should include '[closed] #1 improve diff views' }
      it { should include 'yuroyoro opened this issue Thu Jul 14 20:14:12 +0900 2011' }
      it { should include 'change diff views like github.' }

    end

    context 'given ticket_id with --comments' do

      before {
        github.should_receive(:fetch_json).and_return(json)
        github.should_receive(:fetch_comments).and_return(comments)
        github.show(:ticket_id => 1234, :comments=> true)
      }
      subject { github.sysout.rewind; github.sysout.read }

      it { sysout.length.should_not be_zero }
      it { syserr.length.should be_zero }

      it { should include '[closed] #1 improve diff views' }

    end
  end

  describe '#list' do
    let(:args) { ["list","--status=closed"] }
    let(:sysout) { StringIO.new }
    let(:syserr) { StringIO.new }
    let(:github) { GitIssue::Github.new(args, :apikey => apikey, :user => user, :repo => repo,  :sysout => sysout, :syserr => syserr) }

    let(:issues) {
      {"issues" =>
      [{"body"       => "It appeared two commit has same SHA-1.\r\nThat's maybe branch's commit.",
        "closed_at"  =>"2011/07/20 05:28:42 -0700", "comments"   =>1,
        "created_at" =>"2011/07/20 04:18:23 -0700", "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
        "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/5",
        "labels"     =>["foo","bar"], "number"     =>5, "position"   =>1.0,
        "state"      =>"closed", "title"      =>"Rendered duplicate commit node.",
        "updated_at" =>"2011/07/20 05:28:51 -0700", "user"       =>"yuroyoro", "votes"      =>0},
       {"body"       => "if the 'all' checked ,it will be rendered all other branches that reach from selected branch's commit.\r\nif selected branch is near from first commit, it will be rendered all most commits and branches.\r\nit's too slow and rendered diagram to be large.",
        "closed_at"  =>"2011/07/20 00:06:27 -0700", "comments"   =>1,
        "created_at" =>"2011/07/19 23:21:20 -0700", "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
        "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/4",
        "labels"     =>["bar"], "number"     =>4, "position"   =>1.0, "state"      =>"closed",
        "title"      => "related branche's commit are too many and rendering are too slow.",
        "updated_at" =>"2011/07/20 01:46:10 -0700", "user"       =>"yuroyoro", "votes"      =>0},
       {"body"       => "cytoscapeweb's swf generate javascripts for calling event listener \r\nwhen click event fired.  but generated javascripts doesn't escaped\r\ndouble quote,  then it's to be a invalid syntax and syntax error occurred.\r\n",
        "closed_at"  =>"2011/07/20 01:47:42 -0700", "comments"   =>1,
        "created_at" =>"2011/07/19 23:02:33 -0700", "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
        "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/3",
        "labels"     =>[], "number"     =>3, "position"   =>1.0, "state"      =>"closed",
        "title"      => "script error occurred when commit message includes double quote.",
        "updated_at" =>"2011/07/20 01:47:42 -0700", "user"       =>"yuroyoro", "votes"      =>0},
       {"body"       =>"upgrade to rails3.1.0.rc4.  use coffeescript and scss.",
        "closed_at"  =>"2011/07/20 01:47:53 -0700", "comments"   =>1,
        "created_at" =>"2011/07/14 04:16:23 -0700", "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
        "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/2",
        "labels"     =>[], "number"     =>2, "position"   =>1.0, "state"      =>"closed",
        "title"      =>"upgrade to rails3.1.0", "updated_at" =>"2011/07/20 01:47:53 -0700",
        "user"       =>"yuroyoro", "votes"      =>0},
       {"body"       =>"change diff views like github.",
        "closed_at"  =>"2011/07/20 01:48:05 -0700", "comments"   =>1,
        "created_at" =>"2011/07/14 04:14:12 -0700",
        "gravatar_id"=>"bd3590aaffe8948079d27795cb6f7388",
        "html_url"   =>"https://github.com/yuroyoro/gitterb/issues/1",
        "labels"     =>[], "number"     =>1, "position"   =>1.0, "state"      =>"closed",
        "title"      =>"improve diff views",
        "updated_at" =>"2011/09/12 04:30:41 -0700", "user"       =>"yuroyoro", "votes"      =>0}]}
    }

    context 'given no status' do

      before {
        github.should_receive(:fetch_json).with( URI.join(GitIssue::Github::ROOT, 'issues/list/yuroyoro/gitterb/open')).and_return(issues)

        github.list()
      }
      subject { github.sysout.rewind; github.sysout.read }

      it { sysout.length.should_not be_zero }
      it { syserr.length.should be_zero }

      it { should include "#5     closed  Rendered duplicate commit node.                                    yuroyoro  foo,bar comments:1 votes:0 position:1.0 2011/07/20"}
      it { should include "#4     closed  related branche's commit are too many and rendering are too slow.  yuroyoro  bar     comments:1 votes:0 position:1.0 2011/07/19"}
      it { should include "#3     closed  script error occurred when commit message includes double quote.   yuroyoro          comments:1 votes:0 position:1.0 2011/07/19"}
      it { should include "#2     closed  upgrade to rails3.1.0                                              yuroyoro          comments:1 votes:0 position:1.0 2011/07/14"}
      it { should include "#1     closed  improve diff views                                                 yuroyoro          comments:1 votes:0 position:1.0 2011/07/14"}


    end

    context 'given status' do

      before {
        github.should_receive(:fetch_json).with( URI.join(GitIssue::Github::ROOT, 'issues/list/yuroyoro/gitterb/closed')).and_return(issues)

        github.list(:status => 'closed')
      }
      subject { github.sysout.rewind; github.sysout.read }

      it { sysout.length.should_not be_zero }
      it { syserr.length.should be_zero }
    end
  end



end
