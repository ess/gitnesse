require 'spec_helper'
require 'time'

module Gitnesse
  describe Wiki::Page do
    let(:page) { Wiki::Page.new("~/.gitnesse/gitnesse/features > new_features > new_feature.feature.md") }

    it "converts the filename to a local path" do
      expect(page.relative_path).to eq "./features/new_features"
    end

    it "extracts the feature filename" do
      expect(page.filename).to eq "new_feature.feature"
    end

    it "constructs the full local file path" do
      expect(page.path).to eq "./features/new_features/new_feature.feature"
    end

    describe "#read" do
      it "reads and caches the page's contents" do
        expect(File).to receive(:read).with(page.wiki_path).once.and_return("test")

        expect(page.read).to be_a String
        expect(page.read).to eq "test"
      end
    end

    describe "#write" do
      before do
        @stringio = StringIO.new
        expect(File).to receive(:open).with(page.wiki_path, 'w+').and_yield(@stringio)
        allow(File).to receive(:read).with(page.wiki_path).and_return(@stringio.string)
      end

      it "writes content to the file" do
        page.write('testing')
        expect(page.read).to eq "testing"
      end
    end

    describe "#remove_results" do
      before do
        @stringio = StringIO.new(Support.wiki_feature_with_annotations)
        expect(File).to receive(:read).with(page.wiki_path).and_return(@stringio.string)
        allow(File).to receive(:open).with(page.wiki_path, 'w+').and_yield(@stringio)
      end

      it "removes all existing scenario results from the wiki page" do
        expect(page.remove_results).to eq Support.wiki_feature_without_annotations
      end
    end

    describe "#append_result" do
      before do
        @stringio = StringIO.new(Support.wiki_feature_without_annotations)
        allow(File).to receive(:read).with(page.wiki_path).and_return(@stringio.string)
        allow(File).to receive(:open).with(page.wiki_path, 'w+').and_yield(@stringio)
        allow(Time).to receive(:now).and_return(Time.parse("Sep 06 2013 10:10"))
      end

      it "appends scenario results to the wiki page" do
        page.append_result('Divide two numbers', :passed)
        expect(page.read).to eq Support.wiki_feature_with_annotations
      end

      context "when image_scheme is not set" do
        it "does not set a URL scheme for result images" do
          page.append_result('Divide two numbers', :passed)
          page.read.split("\n").tap do |lines|
            lines.each do |line|
              if line =~ /!\[\]\((.*)\)/
                expect(URI.parse($1).scheme).to be_nil
              end
            end
          end
        end
      end

      context "when image_scheme is http" do
        it "uses http for result images" do
          Config.instance.image_scheme = 'http'
          page.append_result('Divide two numbers', :passed)
          page.read.split("\n").tap do |lines|
            lines.each do |line|
              if line =~ /!\[\]\((.*)\)/
                expect(URI.parse($1).scheme).to eql('http')
              end
            end
          end
        end
      end

      context "when image_scheme is https" do
        it "uses https for result images" do
          Config.instance.image_scheme = 'https'
          page.append_result('Divide two numbers', :passed)
          page.read.split("\n").tap do |lines|
            lines.each do |line|
              if line =~ /!\[\]\((.*)\)/
                expect(URI.parse($1).scheme).to eql('https')
              end
            end
          end
        end
      end
    end
  end
end
