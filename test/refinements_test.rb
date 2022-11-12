require 'helper'

#class TestObjectRefinements
class TestCallerMethodName
  #using OmniAuth::Slack::ObjectRefinements
  include OmniAuth::Slack::CallerMethodName

  def test_caller_method_name_outter
    test_caller_method_name_middle
  end

  def test_caller_method_name_middle
    test_caller_method_name_inner
  end

  def test_caller_method_name_inner
    caller_method_name
  end
end

# describe OmniAuth::Slack::ObjectRefinements do
#   using OmniAuth::Slack::ObjectRefinements
#
#   describe 'caller_method_name' do
#     instance = TestObjectRefinements.new
#     it "gets the name of the method that called the current method" do
#       assert_equal 'test_caller_method_name_middle', instance.test_caller_method_name_outter
#     end
#   end
# end

describe OmniAuth::Slack::CallerMethodName do
  #using OmniAuth::Slack::ObjectRefinements

  describe 'caller_method_name' do
    instance = TestCallerMethodName.new
    it "gets the name of the method that called the current method" do
      assert_equal 'test_caller_method_name_middle', instance.test_caller_method_name_outter
    end
  end
end

describe OmniAuth::Slack::ArrayRefinements do
  using OmniAuth::Slack::ArrayRefinements

  describe 'sort_with' do
    it 'sorts one array according the order of another array' do
      assert_equal [5,2,2,"three","three",1,:four,:four], [1,2,"three",:four,5,:four,2,"three"].sort_with([5,2,"three",1,:four])
    end

    it 'takes an argument for :beginning or :ending to specify where to put un-matched source items' do
      assert_equal [:c, :d, :b, :e, :a], [:a, :b, :c, :d, :e].sort_with([:b, :e, :a], :beginning)
      assert_equal [:b, :e, :a, :c, :d], [:a, :b, :c, :d, :e].sort_with([:b, :e, :a], :ending)
    end
  end
end

describe OmniAuth::Slack::OAuth2Refinements do
  using OmniAuth::Slack::OAuth2Refinements

  describe OAuth2::Response do
    describe 'to_auth_hash' do
      it 'returns parsed response as OmniAuth::Slack::AuthHash' do
        resp = OAuth2::Response.new(a:'data')
        resp.stubs(:parsed).returns({a:'data'})
        assert_kind_of OmniAuth::Slack::AuthHash, resp.to_auth_hash
        assert_equal({a:'data'}[:a], resp.to_auth_hash.a)
      end
    end
  end
end

describe OmniAuth::Slack::StringRefinements do
  using OmniAuth::Slack::StringRefinements

  describe 'words' do
    it 'splits string into array of words based on white-space or commas' do
      assert_equal('scope:one,scope.two scope.three ,scope@four, ,scope-five   scope_six,,,scope/seven , scope#eight'.words,
        ["scope:one", "scope.two", "scope.three", "scope@four", "scope-five", "scope_six", "scope/seven", "scope#eight"]
      )
    end
  end
end
