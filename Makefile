# Makefile for DeepSleep full AI pipeline automation

# Python interpreter
PYTHON=python3
PIP=pip3

# Directories
TOKENIZER_DIR=DeepSleepApp/tokenizer
RESOURCES_DIR=DeepSleepApp/Resources
LOGS_DIR=logs
SCRIPTS_DIR=scripts
SWIFT_TARGET=DeepSleep

.PHONY: all setup tokenizer test-python test-swift dataset preprocess build clean test-e2e test-e2e-coreml test-e2e-swift test-lora test-edge snapshot notify ci

all: setup tokenizer test-python test-swift dataset preprocess test-e2e test-e2e-coreml test-e2e-swift test-lora test-edge snapshot build notify

# Install Python dependencies
setup:
	@echo "🔧 Installing Python dependencies..."
	$(PIP) install faker transformers | tee $(LOGS_DIR)/setup.log

# Step 1: Download and verify tokenizer
tokenizer:
	@echo "🔄 Updating tokenizer..."
	bash $(SCRIPTS_DIR)/tokenizer_update.sh | tee $(LOGS_DIR)/tokenizer_update.log

# Step 2a: Python tokenization tests
test-python: tokenizer
	@echo "🐍 Running Python tokenizer tests..."
	$(PYTHON) $(SCRIPTS_DIR)/tokenization_test.py

# Step 2b: Swift tokenizer tests
test-swift: 
	@echo "🧑‍💻 Running Swift tokenizer tests..."
	xcrun simctl spawn booted xcrun swift run-scripts GPT2Tokenizer | tee $(LOGS_DIR)/tokenizer_swift.log

# Step 3: Dataset generation
dataset:
	@echo "🗄 Generating AI dataset..."
	$(PYTHON) scripts/pipeline/core/dataset_pipeline_integrated.py | tee $(LOGS_DIR)/dataset_generation.log

# Step 4: Dataset preprocessing/tokenization
preprocess: test-python
	@echo "🔄 Preprocessing dataset..."
	$(PYTHON) $(SCRIPTS_DIR)/dataset_preprocess.py | tee $(LOGS_DIR)/dataset_preprocess.log

# Step 2c: End-to-End integration tests
test-e2e: tokenizer test-python
	@echo "🔄 Running E2E integration tests..."
	$(PYTHON) scripts/pipeline/utils/final_integration_test.py | tee $(LOGS_DIR)/e2e_test.log

# Step 2d: CoreML E2E integration tests
test-e2e-coreml: tokenizer
	@echo "🔄 Running CoreML E2E inference tests..."
	$(PYTHON) scripts/run_coreml_inference.py | tee $(LOGS_DIR)/e2e_coreml.log

# Step 2e: Swift E2E integration tests
test-e2e-swift:
	@echo "🔄 Running Swift CoreML E2E tests..."
	xcodebuild -project DeepSleep.xcodeproj -scheme $(SWIFT_TARGET) -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:DeepSleepAppTests/E2ECoreMLTests | tee $(LOGS_DIR)/e2e_swift.log

# Step 3: LoRA and Edge case tests
test-lora:
	@echo "🔄 Running LoRA tests..."
	$(PYTHON) scripts/test_lora_edge_cases.py --lora | tee $(LOGS_DIR)/test_lora.log

test-edge:
	@echo "🔄 Running edge case tests..."
	$(PYTHON) scripts/test_lora_edge_cases.py --edge | tee $(LOGS_DIR)/test_edge.log

# Step 4: Snapshot tests
snapshot:
	@echo "📸 Running snapshot tests..."
	xcodebuild -project DeepSleep.xcodeproj -scheme $(SWIFT_TARGET) -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:UITests | tee $(LOGS_DIR)/snapshot.log

# Step 5: Notifications
notify:
	@echo "🔔 Sending failure notifications..."
	$(PYTHON) scripts/pipeline/utils/notify_slack.py
	$(PYTHON) scripts/pipeline/utils/notify_discord.py

# Step 5: Build iOS app (build only, without tests)
build:
	@echo "📱 Building iOS app..."
	xcodebuild -project DeepSleep.xcodeproj -scheme $(SWIFT_TARGET) -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build | tee $(LOGS_DIR)/xcodebuild.log

# Step 6: CI job (placeholder, invoked by GitHub Actions)
ci: all
	@echo "🚀 CI pipeline completed. All stages passed."

# Clean artifacts
clean:
	@echo "🧹 Cleaning workspace..."
	rm -rf $(TOKENIZER_DIR) $(RESOURCES_DIR)/ko-dialogpt_tokenizer.json $(RESOURCES_DIR)/tokenizer.sha256
	rm -rf deepsleep_ai_dataset.jsonl deepsleep_ai_dataset_tokenized.jsonl
	rm -rf $(LOGS_DIR)/* 