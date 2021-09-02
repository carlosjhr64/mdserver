module Markita
  INLINE = lambda do |line|
    if /`/.match? line
      while md = /`([^`]+)`/.match(line)
        line = md.pre_match + %Q(<code>#{md[1]}</code>) + md.post_match
      end
    elsif not /[<>]/.match? line
      while md = /\*([^*"]+)\*/.match(line)
        line = md.pre_match + %Q(<b>#{md[1]}</b>) + md.post_match
      end
      while md = /\"([^*"]+)\"/.match(line)
        line = md.pre_match + %Q(<i>#{md[1]}</i>) + md.post_match
      end
    end
    while md = /\[([^\[\]<>]+)\]\(([^()<>]+)\)/.match(line)
      line = md.pre_match + %Q(<a href="#{md[2]}">#{md[1]}</a>) + md.post_match
    end
    line.sub(/  $/,'<br>')
  end

  MARKDOWN = Hash.new

  # Empty
  MARKDOWN[/^$/] = lambda do |line, html, file, opt|
    file.gets
  end

  # Ordered list
  MARKDOWN[/^\d+\. /] = lambda do |line, html, file, opt|
    html << "<ol#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^\d+. (.*)$/
      html << "  <li>#{INLINE[$1]}</li>\n"
      line = file.gets
    end
    html << "</ol>\n"
    line
  end

  # Paragraph
  MARKDOWN[/^\[?\w/] = lambda do |line, html, file, opt|
    html << "<p#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^\[?\w/
      html << INLINE[line]
      line = file.gets
    end
    html << "<p>\n"
    line
  end

  # Unordered list
  MARKDOWN[/^\* /] = lambda do |line, html, file, opt|
    html << "<ul#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^[*] (.*)$/
      html << "  <li>#{INLINE[$1]}</li>\n"
      line = file.gets
    end
    html << "</ul>\n"
    line
  end

  # Ballot box
  MARKDOWN[/^- \[x| \] /] = lambda do |line, html, file, opt|
    html << "<ul#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^- \[(x| )\] (.*)$/
      x,t = $1,$2
      li = (x=='x')?
        %q{<li style="list-style-type: '&#9745; '">} :
        %q{<li style="list-style-type: '&#9744; '">}
      html << "  #{li}#{INLINE[t]}</li>\n"
      line = file.gets
    end
    html << "</ul>\n"
    line
  end

  # Definition list
  MARKDOWN[/^: .+:$/] = lambda do |line, html, file, opt|
    html << "<dl#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^: (.*)$/
      line = (($1[-1]==':')? "<dt>#{$1[0..-2]}</dt>\n" : "<dd>#{$1}</dd>\n")
      html << INLINE[line]
      line = file.gets
    end
    html << "</dl>\n"
    line
  end

  # Headers
  MARKDOWN[/^[#]{1,6} /] = lambda do |line, html, file, opt|
    if line.match /^([#]{1,6}) (.*)$/
      i,header = $1.length,$2
      html << "<h#{i}#{opt[:attributes]}>#{INLINE[header]}</h#{i}>\n"
    end
    opt.delete(:attributes)
    file.gets
  end

  # Block-qoute
  MARKDOWN[/^> /] = lambda do |line, html, file, opt|
    html << "<blockquote#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^> (.*)$/
      html << INLINE[$1]
      html << "\n"
      line = file.gets
    end
    html << "</blockquote>\n"
    line
  end

  # Code
  MARKDOWN[/^[`~]{3}\s*(\w+)?$/] = lambda do |line, html, file, opt|
    html << "<pre#{opt[:attributes]}><code>\n"
    opt.delete(:attributes)
    # if line.match /^[`~]{3}\s*\w+?$/
    #   TODO: Rogue syntax highlighting
    # end
    while line = file.gets and not line.match /^[`~]{3}$/
      html << line
    end
    html << "</code></pre>\n"
    # line is either nil or the code close
    line and file.gets
  end

  # Preform
  MARKDOWN[/^ {4}/] = lambda do |line, html, file, opt|
    html << "<pre#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    while line&.match /^ {4}(.*)$/
      html << $1
      html << "\n"
      line = file.gets
    end
    html << "</pre>\n"
    line
  end

  # Horizontal rule
  MARKDOWN[/^---+$/] = lambda do |line, html, file, opt|
    html << "<hr#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    file.gets
  end

  # Table
  MARKDOWN[/^\|.+\|$/] = lambda do |line, html, file, opt|
    html << "<table#{opt[:attributes]}>\n"
    opt.delete(:attributes)
    html << %Q(<thead><tr><th>\n)
    html << line[1...-1].split('|').map{INLINE[_1]}.join('</th><th>')
    html << "\n</th></tr></thead>\n"
    while line = file.gets and line.match /^\|.+\|$/
      html << '<tr><td>'
      html << line[1...-1].split('|').map{INLINE[_1]}.join('</td><td>')
      html << "</td></tr>\n"
    end
    html << "</table>\n"
    line
  end

  # Splits
  MARKDOWN[/^:?\|:?$/] = lambda do |line, html, file, opt|
    case line.chomp
    when '|:'
      html << %Q(<table><tr><td#{opt[:attributes]}>\n)
    when '|'
      html << %Q(</td><td#{opt[:attributes]}>\n)
    when ':|:'
      html << %Q(</td></tr><tr><td#{opt[:attributes]}>\n)
    when ':|'
      html << %Q(</td></tr></table>\n)
    end
    opt.delete(:attributes)
    file.gets
  end

  # Image
  MARKDOWN[/^!\[[^\[\]]+\]\([^\(\)]+\)$/] = lambda do |line, html, file, opt|
    if line.match /^!\[([^\[\]]+)\]\(([^\(\)]+)\)$/
      alt,src=$1,$2
      style = ' '
      case alt
      when /^ .* $/
        style = %Q(style="display: block; margin-left: auto; margin-right: auto;")
      when / $/
        style = %Q( style="float:left;" )
      when /^ /
        style = %Q( style="float:right;" )
      end
      html << %Q(<img src="#{src}"#{style}alt="#{alt.strip}"#{opt[:attributes]}>\n)
    end
    opt.delete(:attributes)
    file.gets
  end

  # Attributes
  MARKDOWN[/^\{: .+\}$/] = lambda do |line, html, file, opt|
    if line.match /^\{:( .*)\}$/
      opt[:attributes] = $1
    end
    file.gets
  end
end
