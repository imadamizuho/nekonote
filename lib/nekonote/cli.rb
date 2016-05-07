# coding: UTF-8

module Nekonote
	def each(path)
		Dir.glob(path).each {|filename| yield filename}
	end
	def check(path, options)
		each(path) do |filename|
			Nekonote::Check.exec filename, options
		end
	end
	def rename(path, options)
		each(path) do |filename|
			Nekonote::Rename.exec filename, options
		end
	end
	def normalize(path, options)
		each(path) do |filename|
			Nekonote::Normalize.exec filename, options
		end
	end
end

class Nekonote::File
	attr_accessor :contents, :encoding
	attr_reader :filename, :dirname, :basename
	attr_writer :contents
	def initialize(filename)
		require 'nkf'
		@filename = filename
		@dirname = File.dirname(filename)
		@basename = File.basename(filename)
		@contents = File.read(@filename, "rw")
		@encoding = NKF.guess(@contents)
		@contents.force_encoding @nkf_guess
		@contents.encode "UTF-8"
	end
	def write(filename)
		open(filename, "wb:#{@encoding}"){|f| f.write contents}
	end
	def rs
		contents =~ /\r\n|\r|\n/
		return $&
	end
	def rs= (rs)
		contents.gsub! /\r\n|\r|\n/, rs
	end
end

module Nekonote::Check
	def exec(filename, options)
		file = Nekonote::File.new(filename)
		name = file.basename
		enc = file.encoding
		rs = file.rs
		error = ""
		error << name_error?(file, options[:name])
		error << enc_error?(file, options[:enc])
		error << rs_error?(file, options[:rs])
		error << moji_error?(file, options[:moji])
		error << re_error?(file, options[:re])
		if options[:diff] != true or error =~ /[^-]/
			error = nil if error.empty?
			path = file.filename if options[:path]
			puts [name, enc, rs, error, path].compact.join("\t")
		end
	end
	def name_error?(file, pattern)
		return "" unless pattern
		return "-" if file.basename =~ Regexp.new(pattern)
		return "N"
	end
	def enc_error?(file, enc)
		return "" unless enc
		return "-" if file.encoding == enc
		return "E"
	end
	def rs_error?(file, rs)
		return "" unless rs
		return "-" unless file.rs
		return "-" if file.rs == rs
		return "S"
	end
	def moji_error?(file, moji)
		return "" unless moji
		require 'moji'
		cond = Moji.module_eval(moji)
		contents.each_char do |char|
			next if char == "\r" or char == "\n"
			return "M" if (Moji.type(ch) & cond).to_i == 0
		end
		return "-"
	end
	def re_error?(file, pattern)
		return "" unless pattern
		return "R" if contents =~ Regexp.new(pattern)
		return "-"
	end
end


module Nekonote::Rename
	def exec(filename, options)
		from = filename
		dirname = File.dirname(from)
		basename = File.basename(from)
		basename = alnum(basename) if options[:alnum]
		basename = upcase(basename) if options[:upcase]
		basename = ext(basename, options) if options[:ext]
		to = File.join(dirname, basename)
		unless from == to
			File.rename filename, dirname + "/" + basename
			puts "rename #{from} to #{to}"
		end
	end
	def upcase(basename)
		basename.upcase
	end
	def alnum(basename)
		basename.tr "Ａ-Ｚａ-ｚ０-９", "A-Za-z0-9"
	end
	def ext(basename, options)
		basename = File.basename(basename, ".*")
		ext = options[:ext].sub(/^\./, "")
		basename + "." + ext
	end
end

module Nekonote::Normalize
	def exec(filename, options)
		file = Nekonote::File.new(filename)
		zen(file) if options[:zen]
		sep(file, options) if options[:sep]
		blank if options[:blank]
		write file, options
	end
	def zen(file)
		require "moji"
		file.contents = file.contents.han_to_zen
	end
	def sep(file, options)
		sep = options[:sep]
		file.contents.gsub! /\r\n|\r|\n/, sep
	end
	def blank(file)
		file.contents.gsub! /[:blank:]+/, "　"
		file.contents.gsub! /[:blank:]+$/, ""
	end
	def write(file, options)
		contents = file.contents
		contents = contents.encode(options[:enc]) if options[:enc]
		filename = File.join(options[:out], file.basename)
		open(, "wb"){|f| f.write contents }
	end
end
