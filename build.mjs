#!/usr/bin/env node
/**
 * Build script for "What can Janet do?" - fetches GitHub data and renders static HTML.
 * Run: node build.mjs
 */

import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const configPath = join(__dirname, 'config.json');
const templatePath = join(__dirname, 'template.html');
const outputPath = join(__dirname, 'index.html');

const config = JSON.parse(readFileSync(configPath, 'utf8'));
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

async function fetchJson(url) {
  const headers = {
    Accept: 'application/vnd.github.v3+json',
    'User-Agent': 'what-can-janet-do-build',
  };
  if (GITHUB_TOKEN) headers.Authorization = `Bearer ${GITHUB_TOKEN}`;
  const res = await fetch(url, { headers });
  if (!res.ok) return null;
  return res.json();
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function stripMarkdown(text) {
  return text
    .replace(/^#+\s+/gm, '')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/^>\s+/gm, '')
    .replace(/\n+/g, ' ')
    .trim();
}

function excerpt(text, maxLen = 400) {
  const plain = stripMarkdown(text);
  if (plain.length <= maxLen) return plain;
  const cut = plain.slice(0, maxLen).lastIndexOf(' ');
  return (cut > 0 ? plain.slice(0, cut) : plain.slice(0, maxLen)) + '…';
}

async function fetchRepoData(owner, repo) {
  const [repoData, readmeData, releaseData] = await Promise.all([
    fetchJson(`https://api.github.com/repos/${owner}/${repo}`),
    fetchJson(`https://api.github.com/repos/${owner}/${repo}/readme`),
    fetchJson(`https://api.github.com/repos/${owner}/${repo}/releases/latest`).catch(() => null),
  ]);
  await sleep(200);

  if (!repoData) return null;

  let description = repoData.description || '';
  if (readmeData?.content && config.readmeMaxLength > 0) {
    try {
      const readmeText = Buffer.from(readmeData.content, 'base64').toString('utf8');
      description = excerpt(readmeText, config.readmeMaxLength);
    } catch (_) {}
  }

  return {
    name: repoData.name,
    fullName: repoData.full_name,
    htmlUrl: repoData.html_url,
    description,
    stars: repoData.stargazers_count ?? 0,
    forks: repoData.forks_count ?? 0,
    release: releaseData
      ? {
          tag: releaseData.tag_name,
          url: releaseData.html_url,
          assets: (releaseData.assets || []).slice(0, 3).map((a) => ({
            name: a.name,
            url: a.browser_download_url,
          })),
        }
      : null,
  };
}

function renderCard(data) {
  const metaParts = [];
  if (config.showStars && data.stars > 0) metaParts.push(`★ ${data.stars}`);
  if (data.forks > 0) metaParts.push(`fork ${data.forks}`);
  const meta = metaParts.length ? `<div class="meta">${metaParts.map((p) => `<span>${p}</span>`).join('')}</div>` : '';

  let releaseHtml = '';
  if (config.showReleases && data.release) {
    const assetLinks = data.release.assets
      .map((a) => `<a href="${escapeHtml(a.url)}">${escapeHtml(a.name)}</a>`)
      .join(', ');
    releaseHtml = `<div class="release">Latest: <a href="${escapeHtml(data.release.url)}">${escapeHtml(data.release.tag)}</a>${assetLinks ? ` · ${assetLinks}` : ''}</div>`;
  }

  return `
            <article class="project-card">
                <h3><a href="${escapeHtml(data.htmlUrl)}">${escapeHtml(data.name)}</a></h3>
                ${meta}
                <p>${escapeHtml(data.description)}</p>
                ${releaseHtml}
            </article>`;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderFooterLinks() {
  return (config.footerLinks || [])
    .map((l) => `<a href="${escapeHtml(l.url)}">${escapeHtml(l.label)}</a>`)
    .join(' · ');
}

async function main() {
  const repos = config.repos || [];
  const cards = [];

  for (const fullName of repos) {
    const [owner, repo] = fullName.split('/');
    if (!owner || !repo) continue;
    const data = await fetchRepoData(owner, repo);
    if (data) cards.push(renderCard(data));
  }

  const template = readFileSync(templatePath, 'utf8');
  const buildTime = new Date().toISOString().replace('T', ' ').slice(0, 19);

  const title = escapeHtml(config.title || 'What can Janet do?');
  const domain = config.domain || 'heyjanet.org';
  const html = template
    .replace(/\{\{TITLE\}\}/g, title)
    .replace('{{TAGLINE}}', escapeHtml(config.tagline || ''))
    .replace('{{BUILD_TIME}}', escapeHtml(buildTime))
    .replace('{{DOMAIN}}', domain)
    .replace('{{REPO_CARDS}}', cards.join('\n'))
    .replace('{{FOOTER_LINKS}}', renderFooterLinks());

  writeFileSync(outputPath, html, 'utf8');
  console.log(`Wrote ${outputPath} (${cards.length} repos)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
