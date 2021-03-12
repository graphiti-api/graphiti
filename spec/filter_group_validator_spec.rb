require "spec_helper"

RSpec.describe Graphiti::Scoping::FilterGroupValidator do
  let(:resource) { double(:resource) }
  let(:query_hash) { {} }
  let(:validator) { described_class.new(resource, query_hash) }

  subject { validator.raise_unless_filter_group_requirements_met! }

  describe '#raise_unless_filter_group_requirements_met!' do
    before do
      allow(resource).to receive(:grouped_filters).and_return(grouped_filters)
    end

    context "when required invalid" do
      let(:query_hash) do
        {
          filter: {
            first_name: {},
            last_name: {}
          }
        }
      end

      let(:grouped_filters) do
        {
          names: [:first_name, :last_name],
          required: :foo
        }
      end

      it "raises an error" do
        expect {
          subject
        }.to raise_error(/The filter group required: value on resource .+ must be one of the following:/)
      end
    end

    context "when all are required" do
      let(:grouped_filters) do
        {
          names: [:first_name, :last_name],
          required: :all
        }
      end

      context "when all are not given in the request" do
        let(:query_hash) do
          {
            filter: {
              first_name: {}
            }
          }
        end

        it "raises an error" do
          expect {
            subject
          }.to raise_error(/All of the following filters must be provided on resource/)
        end
      end

      context "when all are given in the request" do
        let(:query_hash) do
          {
            filter: {
              first_name: {},
              last_name: {}
            }
          }
        end

        it "works" do
          expect(subject).to be true
        end
      end
    end

    context "when any are required" do
      let(:grouped_filters) do
        {
          names: [:first_name, :last_name],
          required: :any
        }
      end

      context "when none are given in the request" do
        let(:query_hash) do
          {
            filter: {}
          }
        end

        it "raises an error" do
          expect {
            subject
          }.to raise_error(/One of the following filters must be provided on resource/)
        end
      end

      context "when one is given in the request" do
        let(:query_hash) do
          {
            filter: {
              last_name: {}
            }
          }
        end

        it "works" do
          expect(subject).to be true
        end
      end

      context "when all are given in the request" do
        let(:query_hash) do
          {
            filter: {
              first_name: {},
              last_name: {}
            }
          }
        end

        it "works" do
          expect(subject).to be true
        end
      end
    end
  end
end
