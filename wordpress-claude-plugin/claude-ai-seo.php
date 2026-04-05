<?php
/**
 * Plugin Name: Claude AI — Генератор контенту та SEO
 * Description: Автогенерація статей українською та SEO-аналіз сторінок за допомогою Claude AI
 * Version: 1.0
 * Author: Your Name
 */

if (!defined('ABSPATH')) exit;

// ─── Меню адмінки ────────────────────────────────────────────────────────────

add_action('admin_menu', function () {
    add_menu_page(
        'Claude AI SEO',
        'Claude AI SEO',
        'manage_options',
        'claude-ai-seo',
        'claude_render_generator',
        'dashicons-edit-large',
        30
    );
    add_submenu_page(
        'claude-ai-seo',
        'Генератор статей',
        'Генератор статей',
        'manage_options',
        'claude-ai-seo',
        'claude_render_generator'
    );
    add_submenu_page(
        'claude-ai-seo',
        'SEO-аналіз',
        'SEO-аналіз',
        'manage_options',
        'claude-seo-analyzer',
        'claude_render_analyzer'
    );
    add_submenu_page(
        'claude-ai-seo',
        'Налаштування',
        'Налаштування',
        'manage_options',
        'claude-ai-settings',
        'claude_render_settings'
    );
});

// ─── Налаштування ────────────────────────────────────────────────────────────

function claude_render_settings() {
    if (isset($_POST['claude_save_settings'])) {
        check_admin_referer('claude_settings');
        update_option('claude_api_key', sanitize_text_field($_POST['claude_api_key']));
        update_option('claude_model', sanitize_text_field($_POST['claude_model']));
        echo '<div class="notice notice-success"><p>Налаштування збережено.</p></div>';
    }
    $api_key = get_option('claude_api_key', '');
    $model   = get_option('claude_model', 'claude-opus-4-6');
    ?>
    <div class="wrap">
        <h1>Налаштування Claude AI</h1>
        <form method="post">
            <?php wp_nonce_field('claude_settings'); ?>
            <table class="form-table">
                <tr>
                    <th>Anthropic API Key</th>
                    <td>
                        <input type="password" name="claude_api_key"
                               value="<?php echo esc_attr($api_key); ?>"
                               class="regular-text" placeholder="sk-ant-...">
                        <p class="description">Отримати на <a href="https://console.anthropic.com" target="_blank">console.anthropic.com</a></p>
                    </td>
                </tr>
                <tr>
                    <th>Модель</th>
                    <td>
                        <select name="claude_model">
                            <option value="claude-opus-4-6" <?php selected($model, 'claude-opus-4-6'); ?>>Claude Opus 4.6 (найкращий)</option>
                            <option value="claude-sonnet-4-6" <?php selected($model, 'claude-sonnet-4-6'); ?>>Claude Sonnet 4.6 (швидший)</option>
                            <option value="claude-haiku-4-5" <?php selected($model, 'claude-haiku-4-5'); ?>>Claude Haiku 4.5 (економний)</option>
                        </select>
                    </td>
                </tr>
            </table>
            <p><input type="submit" name="claude_save_settings" class="button button-primary" value="Зберегти"></p>
        </form>
    </div>
    <?php
}

// ─── Функція виклику Claude API ───────────────────────────────────────────────

function claude_api_request(string $system_prompt, string $user_message): string|WP_Error {
    $api_key = get_option('claude_api_key', '');
    $model   = get_option('claude_model', 'claude-opus-4-6');

    if (empty($api_key)) {
        return new WP_Error('no_key', 'API ключ не вказано. Перейдіть у Налаштування.');
    }

    $response = wp_remote_post('https://api.anthropic.com/v1/messages', [
        'timeout' => 120,
        'headers' => [
            'Content-Type'      => 'application/json',
            'x-api-key'         => $api_key,
            'anthropic-version' => '2023-06-01',
        ],
        'body' => json_encode([
            'model'      => $model,
            'max_tokens' => 4096,
            'system'     => $system_prompt,
            'messages'   => [
                ['role' => 'user', 'content' => $user_message],
            ],
        ]),
    ]);

    if (is_wp_error($response)) {
        return $response;
    }

    $body = json_decode(wp_remote_retrieve_body($response), true);

    if (isset($body['error'])) {
        return new WP_Error('api_error', $body['error']['message']);
    }

    return $body['content'][0]['text'] ?? '';
}

// ─── Генератор статей ─────────────────────────────────────────────────────────

function claude_render_generator() {
    $result = null;
    $error  = null;

    if (isset($_POST['claude_generate'])) {
        check_admin_referer('claude_generate');

        $topic       = sanitize_text_field($_POST['topic']);
        $keywords    = sanitize_text_field($_POST['keywords']);
        $length      = intval($_POST['length']);
        $post_type   = sanitize_text_field($_POST['post_type']);
        $save_draft  = isset($_POST['save_draft']);

        $system = 'Ти — досвідчений SEO-копірайтер, що пише виключно українською мовою.
Твоя задача — створювати якісний, унікальний контент, оптимізований для пошукових систем.
Завжди відповідай ТІЛЬКИ валідним JSON без жодного зайвого тексту.';

        $user = "Напиши SEO-оптимізовану статтю на тему: «{$topic}»

Ключові слова для SEO: {$keywords}
Орієнтовна довжина: {$length} слів

Поверни ТІЛЬКИ JSON такого формату (без markdown, без ```json):
{
  \"title\": \"SEO-заголовок статті (50-60 символів)\",
  \"meta_description\": \"Мета-опис для Google (150-160 символів)\",
  \"slug\": \"url-slug-latinkoyu\",
  \"focus_keyword\": \"головне ключове слово\",
  \"content\": \"Повний HTML-контент статті з тегами h2, h3, p, ul, li\",
  \"tags\": [\"тег1\", \"тег2\", \"тег3\"],
  \"seo_score\": {
    \"title_length\": true,
    \"meta_length\": true,
    \"keyword_in_title\": true,
    \"keyword_in_meta\": true
  }
}";

        $response = claude_api_request($system, $user);

        if (is_wp_error($response)) {
            $error = $response->get_error_message();
        } else {
            $data = json_decode($response, true);
            if ($data) {
                $result = $data;

                if ($save_draft && !empty($data['content'])) {
                    $post_id = wp_insert_post([
                        'post_title'   => wp_strip_all_tags($data['title'] ?? $topic),
                        'post_content' => $data['content'],
                        'post_status'  => 'draft',
                        'post_type'    => $post_type,
                        'post_name'    => $data['slug'] ?? '',
                        'tags_input'   => $data['tags'] ?? [],
                    ]);

                    // Зберегти мета для Yoast SEO / Rank Math
                    if ($post_id && !is_wp_error($post_id)) {
                        update_post_meta($post_id, '_yoast_wpseo_title', $data['title'] ?? '');
                        update_post_meta($post_id, '_yoast_wpseo_metadesc', $data['meta_description'] ?? '');
                        update_post_meta($post_id, '_yoast_wpseo_focuskw', $data['focus_keyword'] ?? '');
                        // Rank Math
                        update_post_meta($post_id, 'rank_math_title', $data['title'] ?? '');
                        update_post_meta($post_id, 'rank_math_description', $data['meta_description'] ?? '');
                        update_post_meta($post_id, 'rank_math_focus_keyword', $data['focus_keyword'] ?? '');

                        $edit_url = get_edit_post_link($post_id);
                        echo '<div class="notice notice-success"><p>✅ Збережено як чернетку. <a href="' . esc_url($edit_url) . '" target="_blank">Редагувати пост</a></p></div>';
                    }
                }
            } else {
                $error = 'Помилка розбору відповіді. Спробуйте ще раз.';
            }
        }
    }
    ?>
    <div class="wrap">
        <h1>🖊 Генератор SEO-статей</h1>

        <form method="post" style="max-width:800px">
            <?php wp_nonce_field('claude_generate'); ?>
            <table class="form-table">
                <tr>
                    <th><label for="topic">Тема статті *</label></th>
                    <td>
                        <input type="text" id="topic" name="topic" class="large-text" required
                               placeholder="напр.: Як вибрати зимові шини для авто">
                    </td>
                </tr>
                <tr>
                    <th><label for="keywords">Ключові слова</label></th>
                    <td>
                        <input type="text" id="keywords" name="keywords" class="large-text"
                               placeholder="напр.: зимові шини, шини для авто, купити шини">
                        <p class="description">Через кому</p>
                    </td>
                </tr>
                <tr>
                    <th><label for="length">Довжина (слів)</label></th>
                    <td>
                        <select id="length" name="length">
                            <option value="500">~500 слів (коротка)</option>
                            <option value="800" selected>~800 слів (стандарт)</option>
                            <option value="1200">~1200 слів (розширена)</option>
                            <option value="2000">~2000 слів (детальна)</option>
                        </select>
                    </td>
                </tr>
                <tr>
                    <th>Тип запису</th>
                    <td>
                        <select name="post_type">
                            <option value="post">Стаття (post)</option>
                            <option value="page">Сторінка (page)</option>
                        </select>
                    </td>
                </tr>
                <tr>
                    <th>Зберегти</th>
                    <td>
                        <label>
                            <input type="checkbox" name="save_draft" checked>
                            Автоматично зберегти як чернетку
                        </label>
                    </td>
                </tr>
            </table>
            <p><input type="submit" name="claude_generate" class="button button-primary button-large" value="✨ Генерувати статтю"></p>
        </form>

        <?php if ($error): ?>
            <div class="notice notice-error"><p>❌ <?php echo esc_html($error); ?></p></div>
        <?php endif; ?>

        <?php if ($result): ?>
            <hr>
            <h2>Результат</h2>
            <div style="background:#fff;padding:20px;border:1px solid #ddd;border-radius:4px;max-width:800px">

                <table class="widefat" style="margin-bottom:15px">
                    <tr>
                        <td><strong>📌 SEO Title</strong></td>
                        <td><?php echo esc_html($result['title'] ?? ''); ?>
                            <small style="color:#666">(<?php echo mb_strlen($result['title'] ?? ''); ?> символів)</small>
                        </td>
                    </tr>
                    <tr>
                        <td><strong>📝 Meta Description</strong></td>
                        <td><?php echo esc_html($result['meta_description'] ?? ''); ?>
                            <small style="color:#666">(<?php echo mb_strlen($result['meta_description'] ?? ''); ?> символів)</small>
                        </td>
                    </tr>
                    <tr>
                        <td><strong>🔑 Фокус-ключове слово</strong></td>
                        <td><?php echo esc_html($result['focus_keyword'] ?? ''); ?></td>
                    </tr>
                    <tr>
                        <td><strong>🏷️ Теги</strong></td>
                        <td><?php echo esc_html(implode(', ', $result['tags'] ?? [])); ?></td>
                    </tr>
                </table>

                <h3>Контент статті</h3>
                <div style="border:1px solid #eee;padding:15px;max-height:400px;overflow-y:auto;background:#fafafa">
                    <?php echo wp_kses_post($result['content'] ?? ''); ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
    <?php
}

// ─── SEO-аналізатор ──────────────────────────────────────────────────────────

function claude_render_analyzer() {
    $analysis = null;
    $error    = null;
    $post_id  = isset($_POST['post_id']) ? intval($_POST['post_id']) : 0;

    if (isset($_POST['claude_analyze']) && $post_id) {
        check_admin_referer('claude_analyze');

        $post    = get_post($post_id);
        $title   = get_the_title($post_id);
        $content = wp_strip_all_tags($post->post_content);
        $url     = get_permalink($post_id);

        // Мета з Yoast або Rank Math
        $meta_desc = get_post_meta($post_id, '_yoast_wpseo_metadesc', true)
                  ?: get_post_meta($post_id, 'rank_math_description', true)
                  ?: '';
        $focus_kw  = get_post_meta($post_id, '_yoast_wpseo_focuskw', true)
                  ?: get_post_meta($post_id, 'rank_math_focus_keyword', true)
                  ?: '';

        $word_count = str_word_count($content);

        $system = 'Ти — SEO-спеціаліст. Аналізуй контент і повертай ТІЛЬКИ валідний JSON без зайвого тексту.';

        $user = "Проаналізуй цю сторінку для SEO (сайт україномовний):

URL: {$url}
Заголовок: {$title}
Мета-опис: {$meta_desc}
Фокус-ключове слово: {$focus_kw}
Кількість слів: {$word_count}
Контент (перші 3000 символів): " . mb_substr($content, 0, 3000) . "

Поверни ТІЛЬКИ JSON (без markdown):
{
  \"score\": 75,
  \"summary\": \"Загальний висновок одним реченням\",
  \"issues\": [
    {\"type\": \"error\", \"text\": \"опис проблеми\"},
    {\"type\": \"warning\", \"text\": \"попередження\"},
    {\"type\": \"ok\", \"text\": \"що добре\"}
  ],
  \"recommendations\": [
    \"Конкретна порада 1\",
    \"Конкретна порада 2\",
    \"Конкретна порада 3\"
  ],
  \"improved_title\": \"Покращений SEO-заголовок\",
  \"improved_meta\": \"Покращений мета-опис\",
  \"suggested_keywords\": [\"ключове слово 1\", \"ключове слово 2\"]
}";

        $response = claude_api_request($system, $user);

        if (is_wp_error($response)) {
            $error = $response->get_error_message();
        } else {
            $analysis = json_decode($response, true);
            if (!$analysis) {
                $error = 'Помилка розбору відповіді.';
            }
        }
    }

    // Список постів і сторінок
    $posts = get_posts([
        'post_type'      => ['post', 'page'],
        'post_status'    => 'publish',
        'posts_per_page' => 100,
        'orderby'        => 'modified',
        'order'          => 'DESC',
    ]);
    ?>
    <div class="wrap">
        <h1>🔍 SEO-аналіз сторінок</h1>

        <form method="post" style="max-width:700px">
            <?php wp_nonce_field('claude_analyze'); ?>
            <table class="form-table">
                <tr>
                    <th><label for="post_id">Оберіть сторінку / пост</label></th>
                    <td>
                        <select id="post_id" name="post_id" class="large-text">
                            <option value="">— Оберіть —</option>
                            <?php foreach ($posts as $p): ?>
                                <option value="<?php echo $p->ID; ?>" <?php selected($post_id, $p->ID); ?>>
                                    [<?php echo esc_html($p->post_type); ?>]
                                    <?php echo esc_html($p->post_title); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </td>
                </tr>
            </table>
            <p><input type="submit" name="claude_analyze" class="button button-primary button-large" value="🔍 Аналізувати"></p>
        </form>

        <?php if ($error): ?>
            <div class="notice notice-error"><p>❌ <?php echo esc_html($error); ?></p></div>
        <?php endif; ?>

        <?php if ($analysis): ?>
            <hr>
            <?php
            $score = intval($analysis['score'] ?? 0);
            $color = $score >= 80 ? '#46b450' : ($score >= 50 ? '#ffb900' : '#dc3232');
            ?>
            <div style="max-width:700px">
                <div style="background:#fff;padding:20px;border:1px solid #ddd;border-radius:4px;margin-bottom:20px">
                    <div style="display:flex;align-items:center;gap:20px;margin-bottom:15px">
                        <div style="width:80px;height:80px;border-radius:50%;background:<?php echo $color; ?>;
                                    display:flex;align-items:center;justify-content:center;
                                    color:#fff;font-size:24px;font-weight:bold">
                            <?php echo $score; ?>
                        </div>
                        <div>
                            <h2 style="margin:0">SEO-рейтинг</h2>
                            <p style="margin:5px 0;color:#666"><?php echo esc_html($analysis['summary'] ?? ''); ?></p>
                        </div>
                    </div>

                    <h3>📋 Перевірки</h3>
                    <?php foreach ($analysis['issues'] ?? [] as $issue):
                        $icons = ['error' => '❌', 'warning' => '⚠️', 'ok' => '✅'];
                        $icon  = $icons[$issue['type']] ?? '•';
                    ?>
                        <div style="padding:8px 0;border-bottom:1px solid #f0f0f0">
                            <?php echo $icon; ?> <?php echo esc_html($issue['text']); ?>
                        </div>
                    <?php endforeach; ?>
                </div>

                <div style="background:#fff;padding:20px;border:1px solid #ddd;border-radius:4px;margin-bottom:20px">
                    <h3>💡 Рекомендації</h3>
                    <ol>
                        <?php foreach ($analysis['recommendations'] ?? [] as $rec): ?>
                            <li style="margin-bottom:8px"><?php echo esc_html($rec); ?></li>
                        <?php endforeach; ?>
                    </ol>
                </div>

                <div style="background:#fff;padding:20px;border:1px solid #ddd;border-radius:4px;margin-bottom:20px">
                    <h3>✏️ Покращені мета-теги</h3>
                    <table class="widefat">
                        <tr>
                            <td><strong>Title</strong></td>
                            <td>
                                <?php echo esc_html($analysis['improved_title'] ?? ''); ?>
                                <small style="color:#666">(<?php echo mb_strlen($analysis['improved_title'] ?? ''); ?> симв.)</small>
                            </td>
                        </tr>
                        <tr>
                            <td><strong>Meta Description</strong></td>
                            <td>
                                <?php echo esc_html($analysis['improved_meta'] ?? ''); ?>
                                <small style="color:#666">(<?php echo mb_strlen($analysis['improved_meta'] ?? ''); ?> симв.)</small>
                            </td>
                        </tr>
                        <tr>
                            <td><strong>Ключові слова</strong></td>
                            <td><?php echo esc_html(implode(', ', $analysis['suggested_keywords'] ?? [])); ?></td>
                        </tr>
                    </table>

                    <?php if ($post_id): ?>
                        <form method="post" style="margin-top:15px">
                            <?php wp_nonce_field('claude_apply_meta'); ?>
                            <input type="hidden" name="apply_post_id" value="<?php echo $post_id; ?>">
                            <input type="hidden" name="apply_title" value="<?php echo esc_attr($analysis['improved_title'] ?? ''); ?>">
                            <input type="hidden" name="apply_meta" value="<?php echo esc_attr($analysis['improved_meta'] ?? ''); ?>">
                            <input type="hidden" name="apply_keyword" value="<?php echo esc_attr(($analysis['suggested_keywords'] ?? [''])[0]); ?>">
                            <input type="submit" name="claude_apply" class="button button-secondary" value="💾 Застосувати мета-теги">
                        </form>
                    <?php endif; ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
    <?php

    // Застосувати мета-теги
    if (isset($_POST['claude_apply'])) {
        check_admin_referer('claude_apply_meta');
        $pid     = intval($_POST['apply_post_id']);
        $a_title = sanitize_text_field($_POST['apply_title']);
        $a_meta  = sanitize_text_field($_POST['apply_meta']);
        $a_kw    = sanitize_text_field($_POST['apply_keyword']);

        update_post_meta($pid, '_yoast_wpseo_title', $a_title);
        update_post_meta($pid, '_yoast_wpseo_metadesc', $a_meta);
        update_post_meta($pid, '_yoast_wpseo_focuskw', $a_kw);
        update_post_meta($pid, 'rank_math_title', $a_title);
        update_post_meta($pid, 'rank_math_description', $a_meta);
        update_post_meta($pid, 'rank_math_focus_keyword', $a_kw);

        echo '<div class="notice notice-success"><p>✅ Мета-теги застосовано до запису.</p></div>';
    }
}
