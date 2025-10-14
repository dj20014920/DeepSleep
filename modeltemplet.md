허깅페이스에 등록된 문서 기준 내용임 참고할 것
1. kexplo/HyperCLOVAX-SEED-Text-Instruct-0.5B-Q4_K_M-GGUF - https://huggingface.co/kexplo/HyperCLOVAX-SEED-Text-Instruct-0.5B-Q4_K_M-GGUF?show_file_info=hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf

hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf 
432 MB

version    3
tensor_count    219
kv_count    34
general.architecture    llama
general.type    model
general.name    HyperCLOVAX SEED Text Instruct 0.5B
general.finetune    Instruct
general.basename    HyperCLOVAX-SEED-Text
general.size_label    0.5B
general.license    other
general.license.name    hyperclovax-seed
general.license.link    LICENSE
general.quantization_version    2
general.file_type    Q4_K_M
llama.block_count    24
llama.context_length    8192
llama.embedding_length    1024
llama.feed_forward_length    4096
llama.attention.head_count    16
llama.attention.head_count_kv    8
llama.attention.layer_norm_rms_epsilon    0.000009999999747378752
llama.attention.key_length    128
llama.attention.value_length    128
llama.rope.freq_base    500000
llama.rope.dimension_count    128
llama.vocab_size    110592
tokenizer.ggml.model    gpt2
tokenizer.ggml.pre    dbrx
tokenizer.ggml.tokens    [!, ", #, $, %, ...]
tokenizer.ggml.token_type    [1, 1, 1, 1, 1, ...]
tokenizer.ggml.merges    [Ġ Ġ, ĠĠ ĠĠ, i n, Ġ t, ĠĠĠĠ ĠĠĠĠ, ...]
tokenizer.ggml.bos_token_id    100257
tokenizer.ggml.eos_token_id    100275
tokenizer.ggml.unknown_token_id    100257
tokenizer.ggml.padding_token_id    100257
tokenizer.ggml.add_space_prefix    false
tokenizer.chat_template    {% if not add_generation_prompt is defined %}{% set add_generation_prompt = false %}{% endif %}{% for message in messages %}{{'<|im_start|>' + message['role'] + ' ' + message['content'] + '<|im_end|>' + ' '}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant ' }}{% endif %}

2. cherryDavid/HyperCLOVAX-SEED-Text-Instruct-0.5B-Q8_0-GGUF -https://huggingface.co/cherryDavid/HyperCLOVAX-SEED-Text-Instruct-0.5B-Q8_0-GGUF?show_file_info=hyperclovax-seed-text-instruct-0.5b-q8_0.gguf

hyperclovax-seed-text-instruct-0.5b-q8_0.gguf
726 MB

version    3
tensor_count    219
kv_count    34
general.architecture    llama
general.type    model
general.name    HyperCLOVAX SEED Text Instruct 0.5B
general.finetune    Instruct
general.basename    HyperCLOVAX-SEED-Text
general.size_label    0.5B
general.license    other
general.license.name    hyperclovax-seed
general.license.link    LICENSE
general.quantization_version    2
general.file_type    Q8_0
llama.block_count    24
llama.context_length    8192
llama.embedding_length    1024
llama.feed_forward_length    4096
llama.attention.head_count    16
llama.attention.head_count_kv    8
llama.attention.layer_norm_rms_epsilon    0.000009999999747378752
llama.attention.key_length    128
llama.attention.value_length    128
llama.rope.freq_base    500000
llama.rope.dimension_count    128
llama.vocab_size    110592
tokenizer.ggml.model    gpt2
tokenizer.ggml.pre    dbrx
tokenizer.ggml.tokens    [!, ", #, $, %, ...]
tokenizer.ggml.token_type    [1, 1, 1, 1, 1, ...]
tokenizer.ggml.merges    [Ġ Ġ, ĠĠ ĠĠ, i n, Ġ t, ĠĠĠĠ ĠĠĠĠ, ...]
tokenizer.ggml.bos_token_id    100257
tokenizer.ggml.eos_token_id    100275
tokenizer.ggml.unknown_token_id    100257
tokenizer.ggml.padding_token_id    100257
tokenizer.ggml.add_space_prefix    false
tokenizer.chat_template    {% if not add_generation_prompt is defined %}{% set add_generation_prompt = false %}{% endif %}{% for message in messages %}{{'<|im_start|>' + message['role'] + ' ' + message['content'] + '<|im_end|>' + ' '}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant ' }}{% endif %}

3.soob3123/amoral-gemma3-1B-v2-gguf - https://huggingface.co/soob3123/amoral-gemma3-1B-v2-gguf?show_file_info=amoral-gemma3-1B-v2-Q5_K_M.gguf

amoral-gemma3-1B-v2-Q5_K_M.gguf
851 MB

version    3
tensor_count    340
kv_count    37
general.architecture    gemma3
general.type    model
general.name    Model
general.size_label    1000M
general.license    apache-2.0
general.base_model.count    1
general.base_model.0.name    Gemma 3 1b It
general.base_model.0.organization    Google
general.base_model.0.repo_url    https://huggingface.co/google/gemma-3-1b-it
general.tags    [text-generation-inference, transformers, gemma3, analytical-tasks, bias-neutralization, ...]
general.languages    [en]
general.quantization_version    2
general.file_type    Q5_K_M
gemma3.context_length    32768
gemma3.embedding_length    1152
gemma3.block_count    26
gemma3.feed_forward_length    6912
gemma3.attention.head_count    4
gemma3.attention.layer_norm_rms_epsilon    9.999999974752427e-7
gemma3.attention.key_length    256
gemma3.attention.value_length    256
gemma3.attention.sliding_window    512
gemma3.attention.head_count_kv    1
gemma3.rope.freq_base    1000000
tokenizer.ggml.model    llama
tokenizer.ggml.pre    default
tokenizer.ggml.tokens    [<pad>, <eos>, <bos>, <unk>, <mask>, ...]
tokenizer.ggml.scores    [-1000, -1000, -1000, -1000, -1000, ...]
tokenizer.ggml.token_type    [3, 3, 3, 3, 3, ...]
tokenizer.ggml.bos_token_id    2
tokenizer.ggml.eos_token_id    106
tokenizer.ggml.unknown_token_id    3
tokenizer.ggml.padding_token_id    0
tokenizer.ggml.add_bos_token    true
tokenizer.ggml.add_eos_token    false
tokenizer.ggml.add_space_prefix    false
tokenizer.chat_template    {{ bos_token }} {%- if messages[0]['role'] == 'system' -%} {%- if messages[0]['content'] is string -%} {%- set first_user_prefix = messages[0]['content'] + ' ' -%} {%- else -%} {%- set first_user_prefix = messages[0]['content'][0]['text'] + ' ' -%} {%- endif -%} {%- set loop_messages = messages[1:] -%} {%- else -%} {%- set first_user_prefix = "" -%} {%- set loop_messages = messages -%} {%- endif -%} {%- for message in loop_messages -%} {%- if (message['role'] == 'user') != (loop.index0 % 2 == 0) -%} {{ raise_exception("Conversation roles must alternate user/assistant/user/assistant/...") }} {%- endif -%} {%- if (message['role'] == 'assistant') -%} {%- set role = "model" -%} {%- else -%} {%- set role = message['role'] -%} {%- endif -%} {{ '<start_of_turn>' + role + ' ' + (first_user_prefix if loop.first else "") }} {%- if message['content'] is string -%} {{ message['content'] | trim }} {%- elif message['content'] is iterable -%} {%- for item in message['content'] -%} {%- if item['type'] == 'image' -%} {{ '<start_of_image>' }} {%- elif item['type'] == 'text' -%} {{ item['text'] | trim }} {%- endif -%} {%- endfor -%} {%- else -%} {{ raise_exception("Invalid content type") }} {%- endif -%} {{ '<end_of_turn> ' }} {%- endfor -%} {%- if add_generation_prompt -%} {{ '<start_of_turn>model ' }} {%- endif -%}

4.yeebwn/HyperCLOVAX-SEED-Text-Instruct-1.5B-Q4_K_M-GGUF - https://huggingface.co/yeebwn/HyperCLOVAX-SEED-Text-Instruct-1.5B-Q4_K_M-GGUF?show_file_info=hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf

hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf
1.01 GB

version    3
tensor_count    218
kv_count    34
general.architecture    llama
general.type    model
general.name    HyperCLOVAX SEED Text Instruct 1.5B
general.finetune    Instruct
general.basename    HyperCLOVAX-SEED-Text
general.size_label    1.5B
general.license    other
general.license.name    hyperclovax-seed
general.license.link    LICENSE
general.quantization_version    2
general.file_type    Q4_K_M
llama.block_count    24
llama.context_length    131072
llama.embedding_length    2048
llama.feed_forward_length    7168
llama.attention.head_count    16
llama.attention.head_count_kv    8
llama.attention.layer_norm_rms_epsilon    0.000009999999747378752
llama.attention.key_length    128
llama.attention.value_length    128
llama.rope.freq_base    100000000
llama.rope.dimension_count    128
llama.vocab_size    110592
tokenizer.ggml.model    gpt2
tokenizer.ggml.pre    dbrx
tokenizer.ggml.tokens    [!, ", #, $, %, ...]
tokenizer.ggml.token_type    [1, 1, 1, 1, 1, ...]
tokenizer.ggml.merges    [Ġ Ġ, ĠĠ ĠĠ, i n, Ġ t, ĠĠĠĠ ĠĠĠĠ, ...]
tokenizer.ggml.bos_token_id    100257
tokenizer.ggml.eos_token_id    100275
tokenizer.ggml.unknown_token_id    100257
tokenizer.ggml.padding_token_id    100257
tokenizer.ggml.add_space_prefix    false
tokenizer.chat_template    {% if not add_generation_prompt is defined %}{% set add_generation_prompt = false %}{% endif %}{% for message in messages %}{{'<|im_start|>' + message['role'] + ' ' + message['content'] + '<|im_end|>' + ' '}}{% endfor %}{% if add_generation_prompt %}{{ '<|im_start|>assistant ' }}{% endif %}
