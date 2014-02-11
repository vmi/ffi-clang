# -*- coding: utf-8 -*-
# Copyright, 2013, by Carlos Martín Nieto <cmn@dwim.me>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'spec_helper'

describe Comment do
	let(:cursor) { Index.new.parse_translation_unit(fixture_path("docs.cc")).cursor }
	let (:comment) { find_first(cursor, :cursor_function).comment }

	it "can be obtained from a cursor" do
		comment.should be_kind_of(Comment)
		comment.should be_kind_of(FullComment)
		comment.kind.should equal(:comment_full)
	end

	it "can parse the brief description" do
		para = comment.child
		para.kind.should equal(:comment_paragraph)
		para.should be_kind_of(ParagraphComment)
		text = para.child
		text.kind.should equal(:comment_text)
		text.should be_kind_of(TextComment)
		text.text.strip.should eq("Short explanation")
	end

	it "can parse the longer description" do
		para = comment.child(1)
		para.kind.should equal(:comment_paragraph)
		para.num_children.should equal(2)
		text = para.child

		lines = (0..para.num_children-1).map do |i|
			para.child(i).text
		end

		lines.should eq([" This is a longer explanation",
				 " that spans multiple lines"])
	end

	it "has working helpers" do
		comment.num_children.should equal(8)

		para = comment.child(1)
		para.text.should eq(" This is a longer explanation\n that spans multiple lines")
	end

	it "understands params" do
		[['input', " some input\n "], ['flags', " some flags\n "]].each_with_index do |v, child_idx|
			param = comment.child(3 + child_idx)
			param.should be_kind_of(ParamCommandComment)

			param.valid_index?.should == true
			param.index.should equal(child_idx)
			param.name.should eq(v[0])
			param.child.text.should eq v[1]
			param.comment.should eq v[1]
		end
	end

	describe "#whitespace?" do
		it "checks the comment is whitespace" do
			expect(comment.child.whitespace?).to be_false
		end
	end

	describe "#has_trailing_newline?" do
		it "checks the content has a traling newline" do
			expect(comment.child.has_trailing_newline?).to be_false
		end
	end

	context 'comment_null' do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'no_comment_function' } }
		let(:comment) { comment_cursor.comment }

		it "is null comment" do
			expect(comment).to be_kind_of(Comment)
			expect(comment.kind).to eq(:comment_null)
			expect(comment.text).to eq('')
		end
	end

	context 'unknown comment type' do
		let(:comment) { 'foobar' }
		it "raises NotImplementedError" do
			expect(Lib).to receive(:comment_get_kind).with(comment).and_return(:xxx_yyy_zzzz)
			expect{Comment.build_from(comment)}.to raise_error(NotImplementedError)
		end
	end

	describe HTMLStartTagComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'b_function' } }
		let(:comment) { comment_cursor.comment }
		let(:paragraph) { comment_cursor.comment.child }
		let(:html_start_tag_comments) { paragraph.children.select{|c| c.kind == :comment_html_start_tag} }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(paragraph).to be_kind_of(ParagraphComment)
			expect(html_start_tag_comments.first).to be_kind_of(HTMLStartTagComment)
			expect(html_start_tag_comments.size).to eq(2)
		end

		describe "#tag" do
			it "returns HTML tag name" do
				expect(html_start_tag_comments[0].tag).to eq('br')
				expect(html_start_tag_comments[1].tag).to eq('a')
			end

			it "is alias method of #name" do
				expect(html_start_tag_comments[0].name).to eq('br')
				expect(html_start_tag_comments[1].name).to eq('a')
			end
		end

		describe "#text" do
			it "returns HTML tag as string" do
				expect(html_start_tag_comments[0].text.strip).to eq('<br/>')
				expect(html_start_tag_comments[1].text.strip).to eq('<a href="http://example.org/">')
			end
		end

		describe "#self_closing?" do
			it "checks the tag is self-closing" do
				expect(html_start_tag_comments[0].self_closing?).to be_true
				expect(html_start_tag_comments[1].self_closing?).to be_false
			end
		end

		describe "#num_attrs" do
			it "returns the number of attributes" do
				expect(html_start_tag_comments[0].num_attrs).to eq(0)
				expect(html_start_tag_comments[1].num_attrs).to eq(1)
			end
		end

		describe "#attrs" do
			it "returns attributes as Array of Hash" do
				expect(html_start_tag_comments[0].attrs).to eq([])
                expect(html_start_tag_comments[1].attrs).to eq([{name: 'href', value: 'http://example.org/'}])
			end
		end
	end

	describe HTMLEndTagComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'b_function' } }
		let(:comment) { comment_cursor.comment }
		let(:paragraph) { comment_cursor.comment.child }
		let(:html_end_tag_comment) { paragraph.children.select{|c| c.kind == :comment_html_end_tag}.first }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(paragraph).to be_kind_of(ParagraphComment)
			expect(html_end_tag_comment).to be_kind_of(HTMLEndTagComment)
		end

		describe "#tag" do
			it "returns HTML tag name" do
				expect(html_end_tag_comment.tag).to eq('a')
			end

			it "is alias method of #name" do
				expect(html_end_tag_comment.name).to eq('a')
			end
		end

		describe "#text" do
			it "returns HTML tag as string" do
				expect(html_end_tag_comment.text.strip).to eq('</a>')
			end
		end
	end

	describe InlineCommandComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'd_function' } }
		let(:comment) { comment_cursor.comment }
		let(:inline_command_comments) { comment.child.children.select{|c| c.kind == :comment_inline_command} }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(comment.child).to be_kind_of(ParagraphComment)
			expect(inline_command_comments.size).to eq(2)
		end

		describe "#name" do
			it "returns the name of the inline command" do
				expect(inline_command_comments[0].name).to eq("em")
				expect(inline_command_comments[1].name).to eq("b")
			end
		end

		describe "#render_kind" do
			it "returns the most appropriate rendering mode" do
				expect(inline_command_comments[0].render_kind).to eq(:emphasized)
				expect(inline_command_comments[1].render_kind).to eq(:bold)
			end
		end

		describe "#num_args" do
			it "returns number of command arguments" do
				expect(inline_command_comments[0].num_args).to eq(1)
				expect(inline_command_comments[1].num_args).to eq(1)
			end
		end

		describe "#args" do
			it "returns arguments as Array" do
				expect(inline_command_comments[0].args).to eq(["foo"])
				expect(inline_command_comments[1].args).to eq(["bar"])
			end
		end

		describe "#text" do
			it "returns readble text" do
				expect(inline_command_comments[0].text.strip).to eq("foo")
				expect(inline_command_comments[1].text.strip).to eq("bar")
			end
		end
	end

	describe VerbatimBlockCommandComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'e_function' } }
		let(:comment) { comment_cursor.comment }
		let(:verb_block_cmd_comment) { comment.children.select{|c| c.kind == :comment_verbatim_block_command}.first }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(verb_block_cmd_comment).to be_kind_of(VerbatimBlockCommandComment)
		end

		describe "#text" do
			it "returns readble text" do
				expect(verb_block_cmd_comment.text).to eq("  foo bar\n  baz")
			end
		end
	end

	describe VerbatimBlockLineComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'e_function' } }
		let(:comment) { comment_cursor.comment }
		let(:verb_block_cmd_comment) { comment.children.select{|c| c.kind == :comment_verbatim_block_command}.first }
		let(:verb_block_line_comments) { verb_block_cmd_comment.children }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(verb_block_cmd_comment).to be_kind_of(VerbatimBlockCommandComment)
			expect(verb_block_line_comments.first).to be_kind_of(VerbatimBlockLineComment)
			expect(verb_block_line_comments.size).to eq(2)
		end

		describe "#text" do
			it "returns readble text" do
				expect(verb_block_line_comments[0].text.strip).to eq("foo bar")
				expect(verb_block_line_comments[1].text.strip).to eq("baz")
			end
		end
	end

	describe VerbatimLine do
	# TODO: how to generate this comment?
	end

	describe ParamCommandComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function and child.spelling == 'a_function' } }
		let(:comment) { comment_cursor.comment }
		let(:param_cmd_comments) { comment.children.select{|c| c.kind == :comment_param_command} }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(param_cmd_comments.first).to be_kind_of(ParamCommandComment)
			expect(param_cmd_comments.size).to eq(4)
		end

		describe "#text" do
			it "returns readble text" do
				expect(param_cmd_comments[0].text.strip).to eq("some input")
				expect(param_cmd_comments[1].text.strip).to eq("some flags")
			end
		end

		describe "#direction_explicit?" do
			it "checks the direction is specified explicitly" do
				expect(param_cmd_comments[0].direction_explicit?).to be_true
				expect(param_cmd_comments[3].direction_explicit?).to be_false
			end
		end

		describe "#direction" do
			it "returns parameter passing direction" do
				expect(param_cmd_comments[0].direction).to eq(:pass_direction_in)
				expect(param_cmd_comments[1].direction).to eq(:pass_direction_out)
				expect(param_cmd_comments[2].direction).to eq(:pass_direction_inout)
				expect(param_cmd_comments[3].direction).to eq(:pass_direction_in)
			end
		end
	end

	describe TParamCommandComment do
		let(:comment_cursor) { find_matching(cursor) { |child, parent|
				child.kind == :cursor_function_template and child.spelling == 'c_function' } }
		let(:comment) { comment_cursor.comment }
		let(:tparam_cmd_comments) { comment.children.select{|c| c.kind == :comment_tparam_command} }

		it "can be obtained from cursor" do
			expect(comment).to be_kind_of(FullComment)
			expect(comment.kind).to equal(:comment_full)
			expect(tparam_cmd_comments.first).to be_kind_of(TParamCommandComment)
			expect(tparam_cmd_comments.size).to eq(3)
		end

		describe "#text" do
			it "returns readble text" do
				expect(tparam_cmd_comments[0].text.strip).to eq("some type of foo")
				expect(tparam_cmd_comments[1].text.strip).to eq("some type of bar")
			end
		end

		describe "#name" do
			it "returns template parameter name" do
				expect(tparam_cmd_comments[0].name).to eq("T1")
				expect(tparam_cmd_comments[1].name).to eq("T2")
				expect(tparam_cmd_comments[2].name).to eq("T3")
			end
		end

		describe "#valid_position?" do
			it "checks this parameter has valid position" do
				expect(tparam_cmd_comments[0].valid_position?).to be_true
			end
		end

		describe "#depth" do
			it "returns nesting depth of this parameter" do
				expect(tparam_cmd_comments[0].depth).to eq(1)
				expect(tparam_cmd_comments[1].depth).to eq(2)
				expect(tparam_cmd_comments[2].depth).to eq(1)
			end
		end

		describe "#index" do
			it "returns index of the parameter at the given nesting depth" do
				expect(tparam_cmd_comments[0].index(0)).to eq(0)
				expect(tparam_cmd_comments[1].index(0)).to eq(1)
				expect(tparam_cmd_comments[1].index(1)).to eq(0)
				expect(tparam_cmd_comments[2].index(0)).to eq(1)
			end
		end
	end
end
