class RstudioServer < Formula
  desc "Integrated development environment (IDE) for R"
  homepage "https://www.rstudio.com"
  head "https://github.com/rstudio/rstudio.git"
  stable do
    url "https://github.com/rstudio/rstudio/archive/v1.3.959.tar.gz"
    sha256 "5c89fe18e3d5ead0e7921c88e5fb42ed816823238e84135f5e9e3a364d35fcc1"
    # upstream has the patch already but it is too big to be merged
    patch :DATA
    # For R 4.0, upstream has the patch already
    patch :p1 do
      url "https://github.com/rstudio/rstudio/commit/3fb2397.diff?full_index=1"
      sha256 "4f7299400c584f6262a7ecdde718e9b72767e7aa4ba6762929d3ec3db773c6c7"
    end
  end

  bottle do
    root_url "https://linuxbrew.bintray.com/bottles-base"
    cellar :any
    sha256 "255ef12e823fc4f2a3e4c3f673cda58cedbd70e15a002ea63d8921a1fb839a85" => :mojave
    sha256 "6326a328ed08563c3ce10624b3a868b03a205bea1b7312baa13c321cbbb10d2a" => :x86_64_linux
  end

  if OS.linux?
    depends_on "patchelf" => :build
    depends_on "libedit"
    depends_on "ncurses"
    depends_on "util-linux" # for libuuid
    depends_on "linux-pam"
  end

  depends_on "adoptopenjdk" => :build if ENV["CI"] && OS.linux?
  depends_on "ant" => :build
  if OS.linux?
    depends_on "boost-rstudio-server"
  elsif OS.mac?
    depends_on "boost-rstudio-server" => :build
  end
  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on :java => ["1.8", :build]
  depends_on "openssl@1.1"
  depends_on "r" => :recommended

  resource "dictionaries" do
    url "https://s3.amazonaws.com/rstudio-buildtools/dictionaries/core-dictionaries.zip"
    sha256 "4341a9630efb9dcf7f215c324136407f3b3d6003e1c96f2e5e1f9f14d5787494"
  end

  resource "mathjax" do
    url "https://s3.amazonaws.com/rstudio-buildtools/mathjax-27.zip"
    sha256 "c56cbaa6c4ce03c1fcbaeb2b5ea3c312d2fb7626a360254770cbcb88fb204176"
  end

  if OS.linux?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.7.3/pandoc-2.7.3-linux.tar.gz"
      sha256 "eb775fd42ec50329004d00f0c9b13076e707cdd44745517c8ce2581fb8abdb75"
    end
  elsif OS.mac?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.7.3/pandoc-2.7.3-macOS.zip"
      sha256 "fb93800c90f3fab05dbd418ee6180d086b619c9179b822ddfecb608874554ff0"
    end
  end

  def which_linux_distribution
    if File.exist?("/etc/redhat-release") || File.exist?("/etc/centos-release")
      "rpm"
    else
      "debian"
    end
  end

  def install
    if ENV["CI"]
      # Reduce memory usage below 4 GB for CI.
      if OS.linux?
        ENV["MAKEFLAGS"] = "-j2"
      elsif OS.mac?
        ENV["MAKEFLAGS"] = "-j4"
      end
    end

    unless build.head?
      ENV["RSTUDIO_VERSION_MAJOR"] = version.to_s.split(".")[0]
      ENV["RSTUDIO_VERSION_MINOR"] = version.to_s.split(".")[1]
      ENV["RSTUDIO_VERSION_PATCH"] = version.to_s.split(".")[2]
    end

    # remove CFLAGS and CXXFLAGS set by java requirement, they break boost library detection
    ENV["CFLAGS"] = ""
    ENV["CXXFLAGS"] = ""

    common_dir = buildpath/"dependencies/common"

    (common_dir/"dictionaries").install resource("dictionaries")
    (common_dir/"mathjax-27").install resource("mathjax")

    resource("pandoc").stage do
      (common_dir/"pandoc/2.7.3/").install "bin/pandoc"
      (common_dir/"pandoc/2.7.3/").install "bin/pandoc-citeproc"
    end

    mkdir "build" do
      args = std_cmake_args
      args << "-DRSTUDIO_TARGET=Server"
      args << "-DRSTUDIO_USE_SYSTEM_BOOST=Yes"
      args << "-DBoost_NO_SYSTEM_PATHS=On"
      args << "-DBOOST_ROOT=#{Formula["boost-rstudio-server"].opt_prefix}"
      args << "-DCMAKE_INSTALL_PREFIX=#{prefix}/rstudio-server"
      args << "-DCMAKE_CXX_FLAGS=-I#{Formula["openssl"].opt_include}"
      args << "-DRSTUDIO_CRASHPAD_ENABLED=0"

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
    daemon = if OS.linux?
      if which_linux_distribution == "rpm"
        <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.redhat.service /etc/systemd/system/
        EOS
      else
        <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.service /etc/systemd/system/
        EOS
      end
    elsif OS.mac?
      <<-EOS

        If it is an upgrade or the plist file exists, unload the plist first
        sudo launchctl unload -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist

        sudo cp #{opt_prefix}/extras/launchd/com.rstudio.launchd.rserver.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist
      EOS
    end

    <<~EOS
      - To test run RStudio Server,
          #{opt_bin}/rserver --server-daemonize=0 --server-data-dir=/tmp/rserver

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


__END__
diff --git a/src/cpp/CMakeLists.txt b/src/cpp/CMakeLists.txt
index af791506eb..5845bdf1a0 100644
--- a/src/cpp/CMakeLists.txt
+++ b/src/cpp/CMakeLists.txt
@@ -317,0 +318 @@ endif()
+if (NOT DEFINED RSTUDIO_CRASHPAD_ENABLED OR RSTUDIO_CRASHPAD_ENABLED)
@@ -338,0 +340 @@ endif()
+endif()
@@ -527 +528,0 @@ endif()
-
