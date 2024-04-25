require "http/server"
require "digest/sha1"

module Temp::ScriptRunner
  VERSION = "0.1.0"

  if !File.directory?("scripts")
    Dir.mkdir("scripts")
  end

  server = HTTP::Server.new do |context|
    if context.request.method == "PATCH"
      script_name = context.request.path
      script_path = "scripts#{script_name}"

      if !File.file?(script_path)
        puts "#{Time.local}: Script not found: #{script_name}"
        context.response.status_code = 404
        next
      end

      key = context.request.query_params["key"]
      real_key = Digest::SHA1.hexdigest(File.read(script_path))

      if File.exists?(script_path)
        script_contents = File.read_lines(script_path)
        key_line = script_contents.find do |line|
          line.starts_with?("# KEY=") || line.starts_with?("// KEY=")
        end

        if key_line
          file_key = key_line.split("=", 2)[1].strip
          if key == file_key
            real_key = file_key
          end
        end
      end

      if key.nil? || key.empty? || key != real_key
        puts "#{Time.local}: Invalid key #{key} for script #{script_name}"
        context.response.print "Invalid key #{key} for script #{script_name}"
        context.response.status_code = 403
        next
      end

      io = IO::Memory.new
      result = Process.run(script_path, output: io)

      context.response.print "#{io.to_s}\n"

      puts "#{Time.local}: Script #{script_name} executed with status \"#{result.success? ? "success" : "failure"}\""
      context.response.print "Script #{script_name} executed with status \"#{result.success? ? "success" : "failure"}\""
      context.response.status_code = result.success? ? 200 : 500
    else
      puts "#{Time.local}: Invalid request: #{context.request.method} #{context.request.path}"
      context.response.status_code = 404
    end
  end

  server.bind_tcp("0.0.0.0", 7488)
  puts "#{Time.local}: Server listening on http://0.0.0.0:7488"
  server.listen
end
