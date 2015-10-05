#
# Author:: Nate Walck (<nate.walck@gmail.com>)
# Copyright:: Copyright (c) 2015 Facebook, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe Chef::Provider::OsxProfile do
  let(:shell_out_success) do
    double('shell_out', :exitstatus => 0, :error? => false)
  end
  describe 'action_create' do
    before(:each) do
      @node = Chef::Node.new
      @events = Chef::EventDispatch::Dispatcher.new
      @run_context = Chef::RunContext.new(@node, {}, @events)

      @new_resource = Chef::Resource::OsxProfile.new("Profile Test", @run_context)
      @provider = Chef::Provider::OsxProfile.new(@new_resource, @run_context)
      @all_profiles = {"_computerlevel"=>
          [{"ProfileDisplayName"=>"ScreenSaver Settings",
            "ProfileIdentifier"=>"com.apple.screensaver",
            "ProfileInstallDate"=>"2015-10-05 23:15:21 +0000",
            "ProfileItems"=>
             [{"PayloadContent"=>
                {"PayloadContentManagedPreferences"=>
                  {"com.apple.screensaver"=>
                    {"Forced"=>[{"mcx_preference_settings"=>{"idleTime"=>0}}]}}},
               "PayloadDisplayName"=>"Custom: (com.apple.screensaver)",
               "PayloadIdentifier"=>"com.apple.screensaver",
               "PayloadType"=>"com.apple.ManagedClient.preferences",
               "PayloadUUID"=>"73fc30e0-1e57-0131-c32d-000c2944c108",
               "PayloadVersion"=>1}],
            "ProfileOrganization"=>"Facebook",
            "ProfileRemovalDisallowed"=>"false",
            "ProfileType"=>"Configuration",
            "ProfileUUID"=>"1781fbec-3325-565f-9022-8aa28135c3cc",
            "ProfileVerificationState"=>"unsigned",
            "ProfileVersion"=>1},
          {"ProfileDisplayName"=>"ScreenSaver Settings",
            "ProfileIdentifier"=>"com.testprofile.screensaver",
            "ProfileInstallDate"=>"2015-10-05 23:15:21 +0000",
            "ProfileItems"=>
             [{"PayloadContent"=>
                {"PayloadContentManagedPreferences"=>
                  {"com.apple.screensaver"=>
                    {"Forced"=>[{"mcx_preference_settings"=>{"idleTime"=>0}}]}}},
               "PayloadDisplayName"=>"Custom: (com.apple.screensaver)",
               "PayloadIdentifier"=>"com.apple.screensaver",
               "PayloadType"=>"com.apple.ManagedClient.preferences",
               "PayloadUUID"=>"73fc30e0-1e57-0131-c32d-000c2944c110",
               "PayloadVersion"=>1}],
            "ProfileOrganization"=>"Facebook",
            "ProfileRemovalDisallowed"=>"false",
            "ProfileType"=>"Configuration",
            "ProfileUUID"=>"1781fbec-3325-565f-9022-8aa28135c3cc",
            "ProfileVerificationState"=>"unsigned",
            "ProfileVersion"=>1}],
      }
      @test_profile = {
      'PayloadIdentifier' => 'com.testprofile.screensaver',
      'PayloadRemovalDisallowed' => false,
      'PayloadScope' => 'System',
      'PayloadType' => 'Configuration',
      'PayloadUUID' => '1781fbec-3325-565f-9022-8aa28135c3cc',
      'PayloadOrganization' => 'Chef',
      'PayloadVersion' => 1,
      'PayloadDisplayName' => 'Screensaver Settings',
      'PayloadContent'=> [
        {
          'PayloadType' => 'com.apple.ManagedClient.preferences',
          'PayloadVersion' => 1,
          'PayloadIdentifier' => 'com.testprofile.screensaver',
          'PayloadUUID' => '73fc30e0-1e57-0131-c32d-000c2944c108',
          'PayloadEnabled' => true,
          'PayloadDisplayName' => 'com.apple.screensaver',
          'PayloadContent' => {
            'com.apple.screensaver' => {
              'Forced' => [
                {
                  'mcx_preference_settings' => {
                    'idleTime' => 0,
                  }
                }
              ]
            }
          }
        }
      ]
      }
      @no_profiles = {"_computerlevel"=>
          [],
      }
      allow(@provider).to receive(:cookbook_file_available?).and_return(true)
      allow(@provider).to receive(:cache_cookbook_profile).and_return('/tmp/test.mobileconfig.remote')
      allow(@provider).to receive(:get_new_profile_hash).and_return(@test_profile)
      allow(@provider).to receive(:get_installed_profiles).and_return(@all_profiles)
      allow(@provider).to receive(:read_plist).and_return(@all_profiles)
      allow(::File).to receive(:unlink).and_return(true)
    end

    it 'should build the get all profiles shellout command correctly' do
      profile_name = 'com.testprofile.screensaver.mobileconfig'
      tempfile = '/tmp/allprofiles.plist'
      @new_resource.profile_name profile_name
      allow(@provider).to receive(:generate_tempfile).and_return(tempfile)
      allow(@provider).to receive(:get_installed_profiles).and_call_original
      allow(@provider).to receive(:read_plist).and_return(@all_profiles)
      expect(@provider).to receive(:shell_out!).with("profiles -P -o '/tmp/allprofiles.plist'")
      @provider.load_current_resource
    end

    it 'should use profile name as profile when no profile is set' do
      profile_name = 'com.testprofile.screensaver.mobileconfig'
      @new_resource.profile_name profile_name
      @provider.load_current_resource
      expect(@new_resource.profile_name).to eql(profile_name)
    end

    it 'should use identifier from specified profile' do
      @new_resource.profile @test_profile
      @provider.load_current_resource
      expect(
        @provider.instance_variable_get(:@new_profile_identifier)
        ).to eql(@test_profile['PayloadIdentifier'])
    end

    it 'should install when not installed' do
      @new_resource.profile @test_profile
      allow(@provider).to receive(:get_installed_profiles).and_return(@no_profiles)
      @provider.load_current_resource
      expect { @provider.run_action(:install) }
    end

    it 'should install when installed but uuid differs' do
      @new_resource.profile @test_profile
      @all_profiles['_computerlevel'][1]['ProfileUUID'] = '1781fbec-3325-565f-9022-9bb39245d4dd'
      @provider.load_current_resource
      expect { @provider.run_action(:install) }
    end

    it 'should build the shellout install command correctly' do
      profile_path = '/tmp/test.mobileconfig'
      @new_resource.profile @test_profile
      # Change the profile so it triggers an install
      @all_profiles['_computerlevel'][1]['ProfileUUID'] = '1781fbec-3325-565f-9022-9bb39245d4dd'
      @provider.load_current_resource
      allow(@provider).to receive(:write_profile_to_disk).and_return(profile_path)
      expect(@provider).to receive(:shell_out).with("profiles -I -F '#{profile_path}'").and_return(shell_out_success)
      @provider.action_install()
    end

    it 'should fail if there is no identifier inside the profile' do
      @test_profile.delete('PayloadIdentifier')
      @new_resource.profile @test_profile
      expect{@provider.run_action(:install)}.to raise_error(RuntimeError)
    end

  end

  describe 'action_remove' do
    before(:each) do
      @node = Chef::Node.new
      @events = Chef::EventDispatch::Dispatcher.new
      @run_context = Chef::RunContext.new(@node, {}, @events)

      @new_resource = Chef::Resource::OsxProfile.new('Profile Test', @run_context)
      @provider = Chef::Provider::OsxProfile.new(@new_resource, @run_context)
      @current_resource = Chef::Resource::OsxProfile.new('Profile Test')
      @provider.current_resource = @current_resource
      @all_profiles = {"_computerlevel"=>
          [{"ProfileDisplayName"=>"ScreenSaver Settings",
            "ProfileIdentifier"=>"com.apple.screensaver",
            "ProfileInstallDate"=>"2015-10-05 23:15:21 +0000",
            "ProfileItems"=>
             [{"PayloadContent"=>
                {"PayloadContentManagedPreferences"=>
                  {"com.apple.screensaver"=>
                    {"Forced"=>[{"mcx_preference_settings"=>{"idleTime"=>0}}]}}},
               "PayloadDisplayName"=>"Custom: (com.apple.screensaver)",
               "PayloadIdentifier"=>"com.apple.screensaver",
               "PayloadType"=>"com.apple.ManagedClient.preferences",
               "PayloadUUID"=>"73fc30e0-1e57-0131-c32d-000c2944c108",
               "PayloadVersion"=>1}],
            "ProfileOrganization"=>"Facebook",
            "ProfileRemovalDisallowed"=>"false",
            "ProfileType"=>"Configuration",
            "ProfileUUID"=>"1781fbec-3325-565f-9022-8aa28135c3cc",
            "ProfileVerificationState"=>"unsigned",
            "ProfileVersion"=>1},
          {"ProfileDisplayName"=>"ScreenSaver Settings",
            "ProfileIdentifier"=>"com.testprofile.screensaver",
            "ProfileInstallDate"=>"2015-10-05 23:15:21 +0000",
            "ProfileItems"=>
             [{"PayloadContent"=>
                {"PayloadContentManagedPreferences"=>
                  {"com.apple.screensaver"=>
                    {"Forced"=>[{"mcx_preference_settings"=>{"idleTime"=>0}}]}}},
               "PayloadDisplayName"=>"Custom: (com.apple.screensaver)",
               "PayloadIdentifier"=>"com.apple.screensaver",
               "PayloadType"=>"com.apple.ManagedClient.preferences",
               "PayloadUUID"=>"73fc30e0-1e57-0131-c32d-000c2944c110",
               "PayloadVersion"=>1}],
            "ProfileOrganization"=>"Facebook",
            "ProfileRemovalDisallowed"=>"false",
            "ProfileType"=>"Configuration",
            "ProfileUUID"=>"1781fbec-3325-565f-9022-8aa28135c3cc",
            "ProfileVerificationState"=>"unsigned",
            "ProfileVersion"=>1}],
      }
      allow(@provider).to receive(:get_installed_profiles).and_return(@all_profiles)
    end

    it 'should use resource name for identifier when not specified' do
      @new_resource.profile_name 'com.testprofile.screensaver'
      @new_resource.action(:remove)
      @provider.load_current_resource
      expect(@provider.instance_variable_get(:@new_profile_identifier)
        ).to eql(@new_resource.profile_name)
    end

    it 'should use specified identifier' do
      @new_resource.identifier 'com.testprofile.screensaver'
      @new_resource.action(:remove)
      @provider.load_current_resource
      expect(@provider.instance_variable_get(:@new_profile_identifier)
        ).to eql(@new_resource.identifier)
    end

    it 'should build the shellout remove command correctly' do
      @new_resource.identifier 'com.testprofile.screensaver'
      @new_resource.action(:remove)
      @provider.load_current_resource
      expect(@provider).to receive(:shell_out).with("profiles -R -p '#{@new_resource.identifier}'").and_return(shell_out_success)
      @provider.action_remove()
    end
  end
end
