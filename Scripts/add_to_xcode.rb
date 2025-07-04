#!/usr/bin/env ruby

require 'xcodeproj'
require 'pathname'

# 사용법 체크
if ARGV.length < 1
  puts "Usage: #{$0} <file_path> [target_group]"
  puts "Example: #{$0} NewFile.swift DeepSleepApp"
  exit 1
end

file_path = ARGV[0]
target_group = ARGV[1] || "DeepSleepApp"

# 프로젝트 찾기
project_path = Dir.glob("*.xcodeproj").first
unless project_path
  puts "Error: No Xcode project found in current directory"
  exit 1
end

begin
  # 프로젝트 열기
  project = Xcodeproj::Project.open(project_path)
  
  # 파일이 존재하는지 확인
  unless File.exist?(file_path)
    puts "Creating file: #{file_path}"
    File.write(file_path, "//\n// #{File.basename(file_path)}\n// Created by add_to_xcode.rb\n//\n\n")
  end
  
  # 상대 경로 계산
  relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(project_path).parent)
  
  # 타겟 그룹 찾기
  group = project.main_group
  target_group.split('/').each do |part|
    found_group = group.children.find { |g| g.display_name == part }
    if found_group
      group = found_group
    else
      # 그룹이 없으면 생성
      group = group.new_group(part)
    end
  end
  
  # 파일이 이미 추가되어 있는지 확인
  existing_file = group.children.find { |f| f.path == relative_path.to_s }
  if existing_file
    puts "File already exists in project: #{file_path}"
  else
    # 파일 참조 추가
    file_ref = group.new_reference(relative_path.to_s)
    puts "Added to project: #{file_path}"
    
    # Swift 파일인 경우 타겟에도 추가
    if file_path.end_with?('.swift', '.m', '.mm', '.c', '.cpp')
      main_target = project.targets.first
      if main_target
        main_target.add_file_references([file_ref])
        puts "Added to target: #{main_target.name}"
      end
    end
  end
  
  # 프로젝트 저장
  project.save
  puts "✅ Project saved!"
  
  # Xcode 새로고침
  system("osascript -e 'tell application \"Xcode\" to activate' -e 'tell application \"System Events\" to keystroke \"u\" using {command down, option down}'")
  
rescue => e
  puts "Error: #{e.message}"
  exit 1
end
