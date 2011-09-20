require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GitIssue::Base do

  class  SampleIts < GitIssue::Base
    def show(options = {});end
    def guess_ticket; 6789 end
  end

  describe '#initialize' do
    context 'specified unknown g ' do
      let(:args) { ["homuhomu", "1234"] }
      it { lambda{ SampleIts.new(args) }.should raise_error }
    end

    context 'specified known g ' do
      let(:args) { ["show", "1234"] }

      subject{ SampleIts.new(args) }

      it { subject.command.name.should == :show }
      its(:tickets) { should == [1234] }
    end

    context 'args is blank' do
      let (:args) { [] }

      subject { SampleIts.new(args) }

      it { subject.command.name.should == :show }
      its(:tickets) { should == [6789]}
    end

    context 'specified number only' do
      let (:args) {["9876"] }

      subject { SampleIts.new(args) }

      it { subject.command.name.should == :show }
      its(:tickets) { should == [9876]}
    end

    context 'specified multipul numbers ' do
      let(:args) { ["1234", "5678", "9999"] }

      subject { SampleIts.new(args) }

      it { subject.command.name.should == :show }
      its(:tickets) { should == [1234, 5678, 9999]}
    end
  end

  describe '#execute' do

    context 'one ticket_id specified' do
      let(:args) { ["show", "1234"] }
      let(:its)  { SampleIts.new(args) }

      it { its.should_receive(:show).with(its.options.merge(:ticket_id => 1234)).once }
      after { its.execute }
    end

    context 'three ticket_ids specified' do
      let(:args) { ["show", "1234", "5678", "9999"] }
      let(:its)  { SampleIts.new(args) }

      it {
        its.should_receive(:show).with(its.options.merge(:ticket_id => 1234)).once
        its.should_receive(:show).with(its.options.merge(:ticket_id => 5678)).once
        its.should_receive(:show).with(its.options.merge(:ticket_id => 9999)).once
      }
      after { its.execute }
    end

  end


end
