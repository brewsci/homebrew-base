class ShinyServer < Formula
  desc "Host Shiny applications over the web"
  homepage "https://rstudio.com/shiny/server"
  url "https://github.com/rstudio/shiny-server/archive/v1.5.13.944.tar.gz"
  sha256 "938c45f60fe7f5e27bccd1a8e16c546c49d4800e3f4e2bbdbdf408c475abf379"

  bottle do
    root_url "https://linuxbrew.bintray.com/bottles-base"
    cellar :any_skip_relocation
    sha256 "5f24c1deec01163473edda4e460f93c4163bf175cc00d8ea60aba64017b465d4" => :catalina
    sha256 "41865ca258b81467e9e24c3d6ddea7b3b7703d62b3d54d0c4a6a4e10c75f9118" => :x86_64_linux
  end

  depends_on "cmake" => :build
  depends_on "node"
  depends_on "r" => :recommended

  patch :DATA

  def install
    mkdir "tmp" do
      system "cmake", "..", "-DCMAKE_INSTALL_PREFIX=#{prefix}"
      system "make"
    end

    mkdir "build"
    system "#{HOMEBREW_PREFIX}/bin/npm", "install"

    cd "tmp" do
      system "make", "install"
    end

    bookmark_state_dir = var/"shiny-server/lib/bookmarks"
    mkdir_p bookmark_state_dir unless bookmark_state_dir.exist?

    conf_content = <<~EOS
      # Instruct Shiny Server to run applications as the user "shiny"
      run_as shiny;

      # Define a server that listens on port 3838
      server {
        listen 3838;

        # Define a location at the base URL
        location / {

          # Host the directory of Shiny Apps stored in this directory
          site_dir #{var}/shiny-server/srv;

          # Log all Shiny output to files in this directory
          log_dir #{var}/shiny-server/log;

          # The directory where bookmark data should be stored.
          bookmark_state_dir #{var}/shiny-server/lib/bookmarks;

          # When a user visits the base URL rather than a particular application,
          # an index of the applications available in this directory will be shown.
          directory_index on;
        }
      }
    EOS

    mkdir_p etc/"shiny-server/" unless (etc/"shiny-server/").exist?
    (etc/"shiny-server/shiny-server.conf.default").atomic_write conf_content
    conf = etc/"shiny-server/shiny-server.conf.default"
    conf.write conf_content unless conf.exist?

    (bin/"shiny-server").write <<~EOS
      #!/bin/sh
      if [ $# -eq 0 ]; then
          exec "#{HOMEBREW_PREFIX}/bin/node" "#{prefix}/shiny-server/lib/main.js" "#{etc}/shiny-server/shiny-server.conf"
      else
          exec "#{HOMEBREW_PREFIX}/bin/node" "#{prefix}/shiny-server/lib/main.js" "$@"
      fi
    EOS
  end

  def caveats
    <<~EOS
      The config file is located at #{etc}/shiny-server/shiny-server.conf
      You might need to change the `run_as` user in the config file.
    EOS
  end
  test do
    system "true"
  end
end


__END__
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 64f226b..3879d78 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -35,2 +35,2 @@ execute_process(COMMAND echo "${CPACK_PACKAGE_VERSION}"
-add_subdirectory(src)
-add_subdirectory(external/pandoc)
+# add_subdirectory(src)
+# add_subdirectory(external/pandoc)
@@ -42 +41,0 @@ install(DIRECTORY assets
-                  ext
@@ -55,6 +54,6 @@ install(DIRECTORY assets
-configure_file(bin/deploy-example.in bin/deploy-example)
-install(PROGRAMS bin/node
-                 bin/npm
-                 bin/shiny-server
-                 "${CMAKE_CURRENT_BINARY_DIR}/bin/deploy-example"
-        DESTINATION shiny-server/bin)
+# configure_file(bin/deploy-example.in bin/deploy-example)
+# install(PROGRAMS bin/node
+#                  bin/npm
+#                  bin/shiny-server
+#                  "${CMAKE_CURRENT_BINARY_DIR}/bin/deploy-example"
+#         DESTINATION shiny-server/bin)
