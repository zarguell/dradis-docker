# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchHelper do
  def options(term:, scope:)
    Hash.new.tap do
      params[:q] = term
      params[:scope] = scope
    end
  end

  describe '.search_filter_path' do
    let(:project) { Project.new(id: 1) }

    # Make #current_project available in SearchHelper
    before { helper.send(:define_singleton_method, :current_project, lambda { Project.new(id: 1) }) }

    %w[all nodes notes issues evidences].each do |scope|
      it "formats correct #{scope} path" do
        expect(helper.search_filter_path(options(term: "test", scope: scope))).
          to eq "/projects/#{project.id}/search?q=test&scope=#{scope}"
      end
    end

    it "returns empty search path when no options provided" do
      expect(helper.search_filter_path).to eq "/projects/#{project.id}/search"
    end
  end

  describe ".format_match_row" do
    describe "if text is greater than 300 chars " do
      it "returns 300 chars including term, when match located in middle" do
        text = "a" * 50
        text += "dradis"
        text += "a" * 290
        term = "dradis"

        new_text = helper.format_match_row(text, term)
        expect(new_text.length).to eq 300
        expect(new_text).to have_content "dradis"
      end

      it "returns 300 chars including term, when match located in the beginning" do
        text = "dradis"
        text += "a" * 500
        term = "dradis"

        new_text = helper.format_match_row(text, term)
        expect(new_text.length).to eq 300
        expect(new_text).to have_content "dradis"
      end

      it "returns 300 chars including term, when match is located at the end" do
        text = "a" * 500
        text += "dradis"
        term = "dradis"

        new_text = helper.format_match_row(text, term)

        expect(new_text.length).to eq 300
        expect(new_text).to have_content "dradis"
      end
    end

    context "if text is in boundaries of 300 chars" do
      it 'return original text' do
        old_text = "a" * 300
        term = "dradis"

        new_text = helper.format_match_row(old_text, term)

        expect(new_text).to eq old_text
      end
    end
  end
end
