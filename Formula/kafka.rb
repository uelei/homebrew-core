class Kafka < Formula
  desc "Publish-subscribe messaging rethought as a distributed commit log"
  homepage "https://kafka.apache.org"
  url "http://mirror.nbtelecom.com.br/apache/kafka/0.10.1.0/kafka_2.11-0.10.1.0.tgz"
  mirror "https://archive.apache.org/dist/kafka/0.10.1.0/kafka_2.11-0.10.1.0.tgz"
  sha256 "6d9532ae65c9c8126241e7b928b118aaa3a694dab08069471f0e61f4f0329390"

  bottle do
    cellar :any_skip_relocation
    sha256 "4fcea199b4a3a9e4eb3aecd280cb82adee79bf222964e615c64c9b2d02e1fdb3" => :sierra
    sha256 "4fcea199b4a3a9e4eb3aecd280cb82adee79bf222964e615c64c9b2d02e1fdb3" => :el_capitan
    sha256 "4fcea199b4a3a9e4eb3aecd280cb82adee79bf222964e615c64c9b2d02e1fdb3" => :yosemite
  end

  depends_on "zookeeper"
  depends_on :java => "1.8+"

  # Related to https://issues.apache.org/jira/browse/KAFKA-2034
  # Since Kafka does not currently set the source or target compability version inside build.gradle
  # if you do not have Java 1.8 installed you cannot used the bottled version of Kafka
  pour_bottle? do
    reason "The bottle requires Java 1.8."
    satisfy { quiet_system("/usr/libexec/java_home --version 1.8 --failfast") }
  end

  def install
    ENV.java_cache

    data = var/"lib"
    inreplace "config/server.properties",
      "log.dirs=/tmp/kafka-logs", "log.dirs=#{data}/kafka-logs"

    inreplace "config/zookeeper.properties",
      "dataDir=/tmp/zookeeper", "dataDir=#{data}/zookeeper"

    # remove Windows scripts
    rm_rf "bin/windows"

    libexec.install "libs"

    prefix.install "bin"
    bin.env_script_all_files(libexec/"bin", Language::Java.java_home_env("1.8+"))
    Dir["#{bin}/*.sh"].each { |f| mv f, f.to_s.gsub(/.sh$/, "") }

    mv "config", "kafka"
    etc.install "kafka"
    libexec.install_symlink etc/"kafka" => "config"

    # create directory for kafka stdout+stderr output logs when run by launchd
    (var+"log/kafka").mkpath
  end

  plist_options :manual => "zookeeper-server-start #{HOMEBREW_PREFIX}/etc/kafka/zookeeper.properties; kafka-server-start #{HOMEBREW_PREFIX}/etc/kafka/server.properties"

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
        <key>ProgramArguments</key>
        <array>
            <string>#{opt_bin}/kafka-server-start</string>
            <string>#{etc}/kafka/server.properties</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>#{var}/log/kafka/kafka_output.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/kafka/kafka_output.log</string>
    </dict>
    </plist>
    EOS
  end

  test do
    ENV["LOG_DIR"] = "#{testpath}/kafkalog"

    (testpath/"kafka").mkpath
    cp "#{etc}/kafka/zookeeper.properties", testpath/"kafka"
    cp "#{etc}/kafka/server.properties", testpath/"kafka"
    inreplace "#{testpath}/kafka/zookeeper.properties", "#{var}/lib", testpath
    inreplace "#{testpath}/kafka/server.properties", "#{var}/lib", testpath

    begin
      fork do
        exec "#{bin}/zookeeper-server-start #{testpath}/kafka/zookeeper.properties > #{logs}/test.zookeeper-server-start.log 2>&1"
      end

      sleep 15

      fork do
        exec "#{bin}/kafka-server-start #{testpath}/kafka/server.properties > #{logs}/test.kafka-server-start.log 2>&1"
      end

      sleep 30

      system "#{bin}/kafka-topics --zookeeper localhost:2181 --create --if-not-exists --replication-factor 1 --partitions 1 --topic test > #{testpath}/kafka/demo.out 2>/dev/null"
      system "echo \"test message\" | #{bin}/kafka-console-producer --broker-list localhost:9092 --topic test 2>/dev/null"
      system "#{bin}/kafka-console-consumer --zookeeper localhost:2181 --topic test --from-beginning --max-messages 1 >> #{testpath}/kafka/demo.out 2>/dev/null"
      system "#{bin}/kafka-topics --zookeeper localhost:2181 --delete --topic test >> #{testpath}/kafka/demo.out 2>/dev/null"
    ensure
      system "#{bin}/kafka-server-stop"
      system "#{bin}/zookeeper-server-stop"
      sleep 10
    end

    assert_match /test message/, IO.read("#{testpath}/kafka/demo.out")
  end
end
