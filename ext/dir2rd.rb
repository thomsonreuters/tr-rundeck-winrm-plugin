#!/usr/bin/ruby

require File.join(File.dirname(__FILE__), 'rd-scm.rb')
require File.join(File.dirname(__FILE__), 'rd2dir.rb')

def dir2jobsxml
  @dir_job_uuids = Set.new
  jobsxml = REXML::Element.new('joblist')
  xml_files = Dir["#{@opt_store}/**/*.xml"]

  xml_files.each { |xml_file|
    job_xml = REXML::Document.new(File.read(xml_file))
    job_xml = job_xml.elements['joblist/job']
    @dir_job_uuids.add(job_xml.elements['uuid'].text)

    project_name_old = job_xml.elements['context'].elements['project'].text
    project_name_new = @opt_project

    if project_name_old != project_name_new
      job_xml.delete_element(job_xml.elements['id'])
      job_xml.delete_element(job_xml.elements['uuid'])
      job_xml.elements['context'].elements['project'].text = @opt_project
    end

    jobsxml.add_element(job_xml)
  }

  jobsxml
end

def jobsxml2rd(jobsxml)
  var_params = Hash.new
  var_files = Hash.new

  var_params['format'] = 'xml'
  var_params['dupeOption'] = 'update'
  var_params['project'] = @opt_project
  var_params['uuidOption'] = 'preserve'

  var_files['xmlBatch'] = jobsxml.to_s

  if @opt_exclusive
    jobstree = rdjobs2tree
    rd_job_uuids = Set.new

    jobstree.each { |group, jobs|
      jobs.each { |job_name, job_xml|
        rd_job_uuids.add(job_xml.elements['job/uuid'].text)
      }
    }

    excess_job_uuids = rd_job_uuids - @dir_job_uuids

    if ! excess_job_uuids.empty?
      var_params['idlist'] = excess_job_uuids.to_a.join(',')

      toapi('/5/jobs/delete',  var_params)
    end
  end

  toapi('/1/jobs/import', var_params, var_files)
end

if __FILE__==$0
  jobsxml = dir2jobsxml
  jobsxml2rd(jobsxml)
end
