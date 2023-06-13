list = []

ARGF.each do |file|
  # General DateTime
  name = File.basename(file.chomp, ".*")
  outfile = if name =~ /^XRecorder_/
    name = name.sub(/^XRecorder_/, "")
    sprintf("%d.%02d.%02d-%02d.%02d.%02d.webm", name[4, 4], name[2, 2], name[0,2], name[9, 2], name[11, 2], name[13, 2])
  elsif name =~ /(\d{2})(\d{2})(\d{4})_(\d{2})(\d{2})(\d{2})/
    sprintf("%d.%02d.%02d-%02d.%02d.%02d.webm", $3, $2, $1, $4, $5, $6)
  else
    name + ".webm"
  end

  list.push({
    in: file.chomp,
    out: outfile
  })
end

pp list