=begin

	Ruby port of miniPDF.py library written by
##########################################################################
####   Felipe Andres Manzano * felipe.andres.manzano@gmail.com        ####
##########################################################################	
	
=end

#For constructing a minimal pdf file
## PDF REference 3rd edition:: 3.2 Objects
class PDFObject
	attr_accessor :n, :v
	def initialize
		@n = nil
		@v = nil
	end

	def to_s
		throw "Fail"	
	end
end

## PDF REference 3rd edition:: 3.2.1 Booleans Objects
class PDFBool < PDFObject
	def initialize(s)
		super()
		@s = s
	end
	
	def to_s
		return true if @s
		return false
	end
end

## PDF REference 3rd edition:: 3.2.2 Numeric Object
class PDFNum < PDFObject
	def initialize(s)
		super()
		@s = s
	end
	
	def to_s
		return @s.to_s
	end
end

## PDF REference 3rd edition:: 3.2.3 String Objects
class PDFString < PDFObject
	def initialize(s)
		super()
		@s = s
	end
		
	def to_s
		return "(#{@s})"
	end
end

## PDF REference 3rd edition:: 3.2.3 String Objects / Hexadecimal Strings
class PDFHexString < PDFObject
	def initialize(s)
		super()
		temp=""
		s.unpack("C*").each {|x| temp += sprintf("%02x",x)}
		@s=temp
	end
	
	def to_s
		return "<#{@s}>"
	end
end

## A convenient type of literal Strings
class PDFOctalString < PDFObject
	def initialize(s)
		super()
		temp=""
		s.unpack("C*").each {|x| temp += sprintf("\\%03o",x)}
		@s=temp
	end
	
	def to_s
		 return "(#{@s})"
	end
end

## PDF REference 3rd edition:: 3.2.5 Array Objects
class PDFName < PDFObject
	def initialize(s)
		super()
		@s = s
	end 
	
	def to_s
		return "/#{@s}"
	end
end

## PDF REference 3rd edition:: 3.2.5 Array Objects
class PDFArray < PDFObject
	def initialize(s)
		super()
		@s = s.dup
	end
	
	def to_s
		return "[#{@s.join(' ')}]"
	end
end

## PDF REference 3rd edition:: 3.2.6 Dictionary Objects
class PDFDict < PDFObject
	def initialize(d={})
		super()
		@dict = d.dup
	end
	
	def add(name,obj)
		@dict[name]=obj
	end
	
	def to_s
		s="<<\n"
		@dict.each{ |k,v| s += " #{PDFName.new(k)} #{v} \n"}
		s +=">>"
		return s
	end
end

## PDF REference 3rd edition:: 3.2.7 Stream Objects
class PDFStream < PDFDict
	def initialize(stream="")
		super()
		@stream = stream
		@filtered = @stream
		@filteres = []
	end
	
	def appendFilter(filter)
		@filteres << filter
		_applyFilters
	end
	
	def _applyFilters()
		@filtered = @stream
		@filteres.each{|f| @filtered = f.encode(@filtered)}
		add('Length', @filtered.length)
		begin
			arr=[]
			@filteres.each {|f| arr << f.name}
			add('Filter', PDFArray.new(arr))	
		end unless 0 == @filteres.length 
	end
	
	def to_s
		_applyFilters
		s = ""
		s += super.to_s
		s += "\nstream\n"
		s += @filtered
		s += "\nendstream"
		return s
	end
end

## PDF REference 3rd edition:: 3.2.8 Null Object
class PDFNull < PDFObject
	def initialize
		super()
	end
	def to_s
		return "null"
	end
end

## PDF REference 3rd edition:: 3.2.9 Indirect Objects
class PDFRef < PDFObject
	def initialize(obj)
		super()
		@obj = [obj] #Don't know why,but works???
	end
	
	def to_s
		return "#{@obj[0].n} #{@obj[0].v} R"
	end
end

## PDF REference 3rd edition:: 3.3 Filters
## Example Filter...
require 'zlib'
class FlateDecode
	attr_reader :name
	def initialize
		@name = PDFName.new("FlateDecode")
	end
	
	def encode(stream)
		return Zlib::Deflate.deflate(stream,Zlib::DEFAULT_COMPRESSION)
	end
	
	def decode(strem)
		return Zlib::Inflate.inflate(strem)
	end
end

## PDF REference 3rd edition:: 3.4 File Structure
## Simplest file structure...
class PDFDoc
	def initialize(version="1.3",obfuscate=0)
		@objs = []
		@info = nil
		@root = nil
		@version = version
	end
	
	def setRoot(root)
		@root = root
	end
	
	def setInfo(info)
		@info = info
	end
	
	def _add(obj)
		throw "Already added!!!" if obj.v != nil or obj.n != nil
		obj.v=0
		obj.n= @objs.length+1
		@objs << obj
	end
	
	def add(obj)
		if obj.kind_of?(Array)
			obj.each{|o| _add(o)}
		else
			_add(obj)
		end

	end
	
	def _header
		return "%PDF-#{@version}\n%\xE7\xF3\xCF\xD3\n"
	end
	
	def to_s
		doc = _header
		xref={}
		@objs.each { |obj|
			xref[obj.n] = doc.length
			doc += "#{obj.n} #{obj.v} obj \n"
			doc += obj.to_s
			doc += "\nendobj\n\n"
		}
		posxref = doc.length
		doc += "xref\n"
		doc += "0 #{@objs.length + 1}\n"
		doc += "0000000000 65535 f \n"
		xref.each_key{|xr| doc += sprintf("%010d %05d n \n",xref[xr],0)}
		doc += "trailer\n"
		trailer = PDFDict.new()
		trailer.add("Size", @objs.length+1)
		trailer.add("Root", PDFRef.new(@root))
		trailer.add("Info", PDFRef.new(@info)) if @info
		doc += trailer.to_s
		doc += "\nstartxref\n#{posxref}\n"
		doc += "%%EOF"
		return doc
	end
end

