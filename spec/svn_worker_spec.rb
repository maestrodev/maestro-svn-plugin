# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#  http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require 'spec_helper'

describe MaestroDev::Plugin::SvnWorker do

  before(:all) do
    Maestro::MaestroWorker.mock!
  end
  
  def checkout
    `svn checkout --non-interactive --trust-server-cert #{@repo_url} #{@local_path}`
  end

  before(:all) do
    # Create a SVN repository for testing
    @repo_path = Dir.mktmpdir("maestro-agent-svn-repo")
    @repo_url = "file://#{@repo_path}"
    `svnadmin create #{@repo_path}`
    tmp_checkout = Dir.mktmpdir("maestro-agent-svn-tmp")
    FileUtils.rm_rf tmp_checkout
    `svn checkout #{@repo_url} #{tmp_checkout}`
    `cd #{tmp_checkout} && mkdir trunk branches && svn add trunk branches && svn commit -m "Init"`
    ('a'..'e').each {|f| `cd #{tmp_checkout} && touch trunk/#{f} && svn add trunk/#{f} && svn commit -m "Init #{f}"`}
    FileUtils.rm_rf tmp_checkout
  end

  before(:each) do
    @local_path = Dir.mktmpdir("maestro-agent-svn")
    FileUtils.rm_rf @local_path
  end

  after(:each) do
    FileUtils.rm_rf @local_path
  end

  after(:all) do
    FileUtils.rm_rf @repo_path
  end

  describe 'checkout()' do

    it 'should detect error if checkout some code fails' do
      workitem = {'fields' => {'path' => @local_path, 'url' => "http://localhost/asdfasdf/asdfasdf/trunk"}}

      subject.perform(:checkout, workitem)      

      workitem['fields']['__error__'].should include("Error Checking Out repo")
      workitem['fields']['__error__'].should include('http://localhost/asdfasdf/asdfasdf/trunk')
      File.exists?(@local_path).should be_false
    end
    
    it 'should checkout some code' do
      workitem = {'fields' => {'path' => @local_path, 'url' => @repo_url}}
      
      subject.perform(:checkout, workitem)      

      workitem['fields']['__error__'].should be_nil
      File.exists?(@local_path).should be_true
    end

    it 'should update some code checked out code' do
      workitem = {'fields' => {'path' => @local_path,
         'url' => @repo_url}
       }
      
      subject.perform(:checkout, workitem)      

      modtime = File.mtime(@local_path)
      workitem['fields']['__error__'].should be_nil
      File.exists?(@local_path).should be_true

      workitem['fields']['clean_working_copy'] = false      

      subject.perform(:checkout, workitem)      

      modtime.should eql(modtime = File.mtime(@local_path))
      workitem['fields']['__error__'].should be_nil
      File.exists?(@local_path).should be_true

      sleep 1
      workitem['fields']['clean_working_copy'] = true

      subject.perform(:checkout, workitem)      
      
      modtime.should_not eql(modtime = File.mtime(@local_path))
      workitem['fields']['__error__'].should be_nil
      File.exists?(@local_path).should be_true
    end
    
    it "should get the latest revision number" do
      workitem = {'fields' => {'path' => @local_path, 'url' => @repo_url}}
      
      subject.perform(:checkout, workitem)      
      
      workitem['fields']['__context_outputs__']['revision'].should_not be_nil
    end

    it "should set not needed if revision is the same" do
      workitem = {'fields' => {'path' => @local_path, 'url' => @repo_url}}

      subject.perform(:checkout, workitem)      
      
      workitem['fields']['__error__'].should be_nil
      workitem['fields']['__previous_context_outputs__'] = {"revision"=>workitem['fields']['__context_outputs__']['revision']}

      subject.expects(:not_needed)

      subject.perform(:checkout, workitem)      
    end

    it 'should checkout some code with given options' do
      path = Dir.mktmpdir("maestro-agent-svn-revd")
      FileUtils.rm_rf path
      workitem = {'fields' => {'path' => path, 
                               'url' => @repo_url,
                               'options' => '-r 5'}}
      
      subject.perform(:checkout, workitem)      
      
      workitem['fields']['__error__'].should be_nil
      File.exists?(path).should be_true
    end
  end


  describe 'copy()' do

    before(:each) do
      checkout
    end

    it 'should svn copy from source to destination' do
      workitem = {'fields' => {'source' => "#{@local_path}/trunk", 'revision' => nil, 'destination' => "#{@local_path}/branches/branch_test_branch", 'message' => ""}}
      
      subject.perform(:copy, workitem)      
      
      workitem['fields']['__error__'].should be_nil
      File.exists?(@local_path+'/branches/branch_test_branch').should be_true
    end

    it 'should copy with given options' do
      workitem = {'fields' => {'source' => "#{@local_path}/trunk",
                              'revision' => nil, 
                              'destination' => "#{@local_path}/branches/branch_test_branch_with_options", 
                              'message' => "",
                              'options' => '-q'}}
      
      subject.perform(:copy, workitem)      
      
      workitem['fields']['__error__'].should be_nil
    end
    
    it 'should detect error if creating a new branch fails' do
      workitem = {'fields' => {'source' => "#{@local_path}/trunk", 'revision' => nil, 'destination' => "#{@local_path}/branches/branch_test_branch", 'message' => "testing svn copy"}}
      
      subject.perform(:copy, workitem)   #it should fail because there shouldnt be a message when svn copying locally

      workitem['fields']['__error__'].should_not be_nil
      File.exists?("#{@local_path}/branches/branch_test_branch").should be_false
    end

  end

  
  
end
