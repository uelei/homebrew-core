class Feedgnuplot < Formula
  desc "Tool to plot realtime and stored data from the command-line."
  homepage "https://github.com/dkogan/feedgnuplot"
  url "https://github.com/dkogan/feedgnuplot/archive/v1.39.tar.gz"
  sha256 "01ebd4dbbb581569be7fecedfa0d9c0168f95a1dfbe1fc099820e7cf7a31b261"

  bottle do
    cellar :any_skip_relocation
    sha256 "3ca77c9ff696f75b5c4837c2116e61f73f2e0d5b5426b88c67e8763e1fce4a10" => :sierra
    sha256 "6966556a04cba4ed5839675595faeceb6265034d544b7cb5123fdd676635d4ac" => :el_capitan
    sha256 "05b365537624871e498c61c8117ab0954dba3437892e593bbde85e1b4aecf9e5" => :yosemite
  end

  depends_on "gnuplot"

  def install
    system "perl", "Makefile.PL", "prefix=#{prefix}"
    system "make"
    system "make", "install"
  end

  test do
    pipe_output("#{bin}/feedgnuplot --terminal 'dumb 80,20' --exit", "seq 5", 0)
  end
end
