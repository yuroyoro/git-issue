require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe GitIssue do
  describe '#main' do

    context 'unless configured values' do
      ATTRS = %w[type apikey]
      ATTRS.each do |attr|
        context 'config issue.type does not configured' do
          it {
            GitIssue.should_receive(:configured_value).with(attr).and_return("")
            (ATTRS - [attr]).each do |v|
              GitIssue.should_receive(:configured_value).with(v).and_return("some value")
            end
            lambda { GitIssue.main([]) }.should raise_error(SystemExit)
          }
        end
      end
    end

    context 'invalid issue.type' do
      it {
        ATTRS.each do |attr|
          GitIssue.should_receive(:configured_value).with(attr).and_return("some value")
        end
        lambda { GitIssue.main([]) }.should raise_error(SystemExit)
      }
    end

  end

  describe '#its_klass_of' do
    context 'unknown type' do
      specify { lambda { GitIssue.its_klass_of("unknown_type") }.should raise_error }
    end

    context 'type is redmine' do
      subject { GitIssue.its_klass_of("redmine") }
      it { should == GitIssue::Redmine }
    end

    context 'type is github' do
      subject { GitIssue.its_klass_of("github") }
      it { should == GitIssue::Github}
    end

  end
end
