require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe GitIssue do
  describe '#main' do
    context 'config issue.type does not configured' do
      it{
        GitIssue::Helper.should_receive(:configured_value).with("type").and_return("")
        GitIssue::Helper.should_receive(:configured_value).with("apikey").and_return("some value")
        GitIssue::Helper.should_receive(:configure_error).with( "type (redmine | github)",  "git config issue.type redmine")
        lambda { GitIssue.main([]) }.should raise_error(SystemExit)
      }
    end

    context 'invalid issue.type' do
      it{
        GitIssue::Helper.should_receive(:configured_value).with("type").and_return("unknown-type")
        GitIssue::Helper.should_receive(:configured_value).with("apikey").and_return("some value")
        lambda { GitIssue.main([]) }.should raise_error(SystemExit)
      }
    end
  end

  describe '#its_klass_of' do
    context 'unknown type' do
      specify { lambda { GitIssue::Helper.its_klass_of("unknown_type") }.should raise_error }
    end

    context 'type is redmine' do
      subject { GitIssue::Helper.its_klass_of("redmine") }
      it { should == GitIssue::Redmine }
    end

    context 'type is github' do
      subject { GitIssue::Helper.its_klass_of("github") }
      it { should == GitIssue::Github}
    end

  end
end
