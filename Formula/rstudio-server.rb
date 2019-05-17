class RstudioServer < Formula
  desc "Integrated development environment (IDE) for R"
  homepage "https://www.rstudio.com"
  url "https://github.com/rstudio/rstudio/archive/v1.2.1335.tar.gz"
  sha256 "f124fbae68762d0a1fc9a7dc72ad290aebde768e262df87acda3883a07fdfd58"

  bottle do
    root_url "https://linuxbrew.bintray.com/bottles-base"
    sha256 "775c25ca7e41cd3d3ecff84b08656d8f535f0379180f6e175839a6139eea5ae2" => :sierra_or_later
    sha256 "83e33735de324a1316b9875057ad02eb42459249ac8caf80034a7275daf67ef5" => :x86_64_linux
  end

  if OS.linux?
    if ENV["CIRCLECI"] || ENV["TRAVIS"]
      depends_on "jdk@8" => :build
    end
    depends_on "patchelf" => :build
    depends_on "libedit"
    depends_on "ncurses"
    depends_on "util-linux" # for libuuid
    depends_on "linuxbrew/extra/linux-pam"
  end

  depends_on "ant" => :build
  if OS.linux?
    depends_on "boost-rstudio-server"
  elsif OS.mac?
    depends_on "boost-rstudio-server" => :build
  end
  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on :java => ["1.8", :build]
  depends_on :macos if ENV["CIRCLECI"]
  depends_on "openssl"
  depends_on "r" => :recommended

  resource "gin" do
    url "https://s3.amazonaws.com/rstudio-buildtools/gin-2.1.2.zip"
    sha256 "b98e704164f54be596779696a3fcd11be5785c9907a99ec535ff6e9525ad5f9a"
  end

  resource "gwt" do
    url "https://s3.amazonaws.com/rstudio-buildtools/gwt-2.8.1.zip"
    sha256 "0b7af89fdadb4ec51cdb400ace94637d6fe9ffa401b168e2c3d372392a00a0a7"
  end

  resource "junit" do
    url "https://s3.amazonaws.com/rstudio-buildtools/junit-4.9b3.jar"
    sha256 "dc566c3f5da446defe36c534f7ee19cdfe7e565020038b2ef38f01bc9c070551"
  end

  resource "dictionaries" do
    url "https://s3.amazonaws.com/rstudio-buildtools/dictionaries/core-dictionaries.zip"
    sha256 "4341a9630efb9dcf7f215c324136407f3b3d6003e1c96f2e5e1f9f14d5787494"
  end

  resource "mathjax" do
    url "https://s3.amazonaws.com/rstudio-buildtools/mathjax-26.zip"
    sha256 "939a2d7f37e26287970be942df70f3e8f272bac2eb868ce1de18bb95d3c26c71"
  end

  if OS.linux?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.3.1/pandoc-2.3.1-linux.tar.gz"
      sha256 "859609cdba5af61aefd7c93d174e412d6a38f5c1be90dfc357158638ff5e7059"
    end
  elsif OS.mac?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.3.1/pandoc-2.3.1-macOS.zip"
      sha256 "bc9ba6f1f4f447deff811554603edcdb13344b07b969151569b6e46e1c8c81b7"
    end
  end

  def which_linux_distribution
    if File.exist?("/etc/redhat-release") || File.exist?("/etc/centos-release")
      distritbuion = "rpm"
    else
      distritbuion = "debian"
    end
    distritbuion
  end

  # fix build failure with latest macOS compiler
  patch do
    url "https://github.com/rstudio/rstudio/commit/b3b1ef10ca8473b6cf02b22cdb57f871f0237a02.diff?full_index=1"
    sha256 "37c58b7f31307db369ba8c5269f5c303838e06d5db44429766b0213ea6eb6c34"
  end

  def install
    # Reduce memory usage below 4 GB for CI.
    ENV["MAKEFLAGS"] = "-j2" if ENV["CIRCLECI"] || ENV["TRAVIS"]

    unless build.head?
      ENV["RSTUDIO_VERSION_MAJOR"] = version.to_s.split(".")[0]
      ENV["RSTUDIO_VERSION_MINOR"] = version.to_s.split(".")[1]
      ENV["RSTUDIO_VERSION_PATCH"] = version.to_s.split(".")[2]
    end

    # remove CFLAGS and CXXFLAGS set by java requirement, they break boost library detection
    ENV["CFLAGS"] = ""
    ENV["CXXFLAGS"] = ""

    gwt_lib = buildpath/"src/gwt/lib/"
    (gwt_lib/"gin/2.1.2").install resource("gin")
    (gwt_lib/"gwt/2.8.1").install resource("gwt")
    gwt_lib.install resource("junit")

    common_dir = buildpath/"dependencies/common"

    (common_dir/"dictionaries").install resource("dictionaries")
    (common_dir/"mathjax-26").install resource("mathjax")

    resource("pandoc").stage do
      (common_dir/"pandoc/2.3.1/").install "bin/pandoc"
      (common_dir/"pandoc/2.3.1/").install "bin/pandoc-citeproc"
    end

    mkdir "build" do
      args = ["-DRSTUDIO_TARGET=Server", "-DCMAKE_BUILD_TYPE=Release"]
      args << "-DRSTUDIO_USE_SYSTEM_BOOST=Yes"
      args << "-DBoost_NO_SYSTEM_PATHS=On"
      args << "-DBOOST_ROOT=#{Formula["boost-rstudio-server"].opt_prefix}"
      args << "-DCMAKE_INSTALL_PREFIX=#{prefix}/rstudio-server"
      args << "-DCMAKE_CXX_FLAGS=-I#{Formula["openssl"].opt_include}"

      linkerflags = "-DCMAKE_EXE_LINKER_FLAGS=-L#{Formula["openssl"].opt_lib}"
      if OS.linux?
        linkerflags += " -L#{Formula["linux-pam"].opt_lib}" if build.with? "linux-pam"
      end
      args << linkerflags

      args << "-DPAM_INCLUDE_DIR=#{Formula["linux-pam"].opt_include}" if build.with? "linux-pam"

      system "cmake", "..", *args
      system "make", "install"
    end

    bin.install_symlink prefix/"rstudio-server/bin/rserver"
    bin.install_symlink prefix/"rstudio-server/bin/rstudio-server"
    prefix.install_symlink prefix/"rstudio-server/extras"
  end

  def post_install
    # patch path to rserver
    Dir.glob(prefix/"extras/**/*") do |f|
      if File.file?(f) && !File.readlines(f).grep(/#{prefix/"rstudio-server/bin/rserver"}/).empty?
        inreplace f, /#{prefix/"rstudio-server/bin/rserver"}/, opt_bin/"rserver"
      end
    end
  end

  def caveats
    if OS.linux?
      if which_linux_distribution == "rpm"
        daemon = <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.redhat.service /etc/systemd/system/
        EOS
      else
        daemon = <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.service /etc/systemd/system/
        EOS
      end
    elsif OS.mac?
      daemon = <<-EOS

        If it is an upgrade or the plist file exists, unload the plist first
        sudo launchctl unload -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist

        sudo cp #{opt_prefix}/extras/launchd/com.rstudio.launchd.rserver.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist
      EOS
    end

    <<~EOS
      - To test run RStudio Server,
          #{opt_bin}/rserver --server-daemonize=0

      - To complete the installation of RStudio Server
          1. register RStudio daemon#{daemon}
          2. install the PAM configuration
              sudo cp #{opt_prefix}/extras/pam/rstudio /etc/pam.d/

          3. sudo rstudio-server start

      - In default, only users with id >1000 are allowed to login. To relax the
        requirement, add the following line to the configuration file located
        at `/etc/rstudio/rserver.conf`

          auth-minimum-user-id=500
    EOS
  end

  test do
    system "#{bin}/rstudio-server", "version"
  end
end
