# frozen_string_literal: true

# Monkey patch to fix Ferrum::JavaScriptError when response is nil
# This happens when the browser connection is lost during error handling
# This file is loaded after Cuprite loads Ferrum
module Ferrum
  class JavaScriptError
    alias original_initialize initialize

    def initialize(*args)
      response = args.first
      # Handle case where response is nil (browser connection lost)
      if response.nil?
        @class_name = 'ConnectionError'
        @message = 'Browser connection lost during error handling'
      else
        original_initialize(*args)
      end
    end
  end
end
