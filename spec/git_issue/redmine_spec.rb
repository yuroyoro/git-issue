require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GitIssue::Redmine do

  let(:apikey) { "ABCDEFG1234567890" }
  let(:url) { "http://example.com/redmine" }

  describe '#initialize' do
    context 'ginve no apikey ' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Redmine.new(args) }.should raise_error }
    end

    context 'given no url' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Redmine.new(args, :apikey => apikey) }.should raise_error }
    end

    context 'given apikey and url' do
      let(:args) { ["show", "1234"] }
      it { lambda{ GitIssue::Redmine.new(args, :apikey => apikey, :url => url) }.should_not raise_error }
    end
  end

  describe '#show' do
    let(:args) { ["show", "1234"] }
    let(:sysout) { StringIO.new }
    let(:syserr) { StringIO.new }
    let(:redmine) { GitIssue::Redmine.new(args, :apikey => apikey, :url => url, :sysout => sysout, :syserr => syserr) }

    context 'given no ticket_id' do
      it { lambda {redmine.show() }.should raise_error }
    end

    context 'given ticket_id' do
      let(:json) {{
        'issue' => {
          'id' => 1234,
          'status'=>{'name'=>'新規', 'id'=>1},
          'category'=>{'name'=>'カテゴリ', 'id'=>3},
          'assigned_to'=>{'name'=>'Tomohito Ozaki', 'id'=>13},
          'project' => {'name' => 'Testプロジェクト', 'id' => 9},
          'priority'=>{'name'=>'通常', 'id'=>4},
          'author' => {'name' => 'author hoge', 'id' => 3},
          'committer' => {'name' => 'committer fuga', 'id' => 4},
          'tracker' => {'name' => 'Bug', 'id' => 5},
          'subject' => 'new演算子が乳演算子だったらプログラマもっと増えてた',
          'description'=>'(　ﾟ∀ﾟ)o彡°おっぱい！おっぱい！',
          'created_on'=>'2008/08/03 04:08:39 +0900',
          'updated_on'=>'2011/03/02 23:22:49 +0900',
          'done_ratio'=>0,
          'custom_fields'=>
           [{'name'=>'Complete', 'id'=>1, 'value'=>'0'},
            {'name'=>'Due assign', 'id'=>2, 'value'=>'yyyy/mm/dd'},
            {'name'=>'Due close', 'id'=>3, 'value'=>'yyyy/mm/dd'},
            {'name'=>'Resolution', 'id'=>4, 'value'=>''}
           ]
        }
      }}

      it {
        redmine.should_receive(:fetch_json).and_return(json)
        redmine.show(:ticket_id => 1234)
        sysout.length.should_not be_zero
        syserr.length.should be_zero
      }

    end
  end
end
