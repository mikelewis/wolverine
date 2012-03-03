require File.join(File.expand_path('../../test_helper', __FILE__))
require 'digest/sha1'

module Wolverine
  class ScriptTest < MiniTest::Unit::TestCase
    CONTENT = "return 1"
    DIGEST = Digest::SHA1.hexdigest(CONTENT)

    def setup
      Wolverine::Script.any_instance.stubs(:load_lua => CONTENT)
    end

    def script
      @script ||= Wolverine::Script.new('file1')
    end

    def test_error
      base = Pathname.new('/a/b/c/d')
      file = Pathname.new('/a/b/c/d/e/file1.lua')
      Wolverine.config.script_path = base
      redis = stub
      redis.expects(:evalsha).raises(%q{ERR Error running script (call to f_178d75adaa46af3d8237cfd067c9fdff7b9d504f): [string "func definition"]:1: attempt to compare nil with number})
      begin
        script = Wolverine::Script.new(file)
        script.call(redis)
      rescue Wolverine::LuaError => e
        assert_equal "attempt to compare nil with number", e.message
        assert_equal "/a/b/c/d/e/file1.lua:1", e.backtrace.first
        assert_match /script.rb/, e.backtrace[1]
      end
    end

    def test_call_with_cache_hit
      tc = self
      redis = Class.new do
        define_method(:evalsha) do |digest, size, *args|
          tc.assert_equal DIGEST, digest
          tc.assert_equal 2, size
          tc.assert_equal [:a, :b], args
        end
      end
      script.call(redis.new, :a, :b)
    end

    def test_call_with_cache_miss
      tc = self
      redis = Class.new do
        define_method(:evalsha) do |*|
          raise "NOSCRIPT No matching script. Please use EVAL."
        end
        define_method(:eval) do |content, size, *args|
          tc.assert_equal CONTENT, content
          tc.assert_equal 2, size
          tc.assert_equal [:a, :b], args
        end
      end
      script.call(redis.new, :a, :b)
    end

  end
end
