// @ts-check
const {themes} = require('prism-react-renderer');

const codeBlockTheme = (theme, backgroundColor) => ({
  ...theme,
  plain: {...theme.plain, backgroundColor},
});

// Docusaurus prepends baseUrl to navbar and Link hrefs, but not to raw HTML
// like announcementBar content, so that markup has to build its own absolute
// paths. Always has a trailing slash.
const baseUrl = process.env.DOCS_BASE_URL || '/';

// The theme's strikethrough and underline on diff lines are inline styles, so
// CSS cannot undo them. Colour and the +/- signs already carry it.
const withoutDiffDecoration = (theme) => ({
  ...theme,
  styles: theme.styles.map(({types, style}) =>
    types.some((type) => type === 'inserted' || type === 'deleted')
      ? {types, style: {...style, textDecorationLine: undefined}}
      : {types, style}
  ),
});

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Graphiti',
  tagline: 'Stylish Graph APIs',
  favicon: 'img/favicon.ico',

  // Apex, matching the CNAME. This feeds canonical tags and sitemap.xml, so it
  // has to agree with the host actually serving the site or the two split
  // search ranking between them.
  url: 'https://graphiti.dev',
  // graphiti.dev resolves to this repo, so the site serves from the root.
  // DOCS_BASE_URL still overrides it for a build served from the project-pages
  // path, which is what /graphiti/ was during the beta.
  baseUrl,
  organizationName: 'graphiti-api',
  projectName: 'graphiti',

  onBrokenLinks: 'warn',
  markdown: {hooks: {onBrokenMarkdownLinks: 'warn'}},

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          // markdown lives at the repo root, next to the code it documents
          path: '../docs',
          routeBasePath: '/',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/graphiti-api/graphiti/tree/main/docs/',
          // Unversioned docs serve at the root, and would otherwise be
          // labelled "Next" in the dropdown. Once `npm run docusaurus
          // docs:version 2.0` cuts a version, that becomes the root and the
          // working copy moves to /next.
          versions: {current: {label: '2.0'}},
        },
        blog: false,
        theme: {customCss: require.resolve('./src/css/custom.css')},
      }),
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        // The 1.x Jekyll site served /guides/* and /cookbooks/*, and early 2.0
        // drafts served /quickstart and /cheatsheet. Keep those URLs alive.
        // Nothing under /1.13/ is touched: that is the frozen 1.x site.
        redirects: [
          {from: ['/quickstart'], to: '/getting-started/first-api'},
          {from: ['/cheatsheet', '/guides', '/guides/index'], to: '/'},
          {from: ['/guides/overview'], to: '/concepts/overview'},
          {from: ['/guides/why'], to: '/reference/why'},
          {from: ['/guides/vandal'], to: '/reference/vandal'},
          {from: ['/guides/upgrading', '/guides/upgrading-2-0', '/reference/upgrading-2-0', '/upgrading/controllers', '/upgrading/testing', '/upgrading/persistence-hooks', '/upgrading/exception-handling', '/upgrading/belongs-to-linkage', '/upgrading/without-rails'], to: '/upgrading'},
          {from: ['/guides/getting-started/installation'], to: '/getting-started/installation'},

          {from: ['/guides/concepts/resources'], to: '/concepts/resources'},
          {from: ['/guides/concepts/endpoints'], to: '/concepts/endpoints'},
          {from: ['/guides/concepts/links'], to: '/concepts/links'},
          {from: ['/guides/concepts/backends-and-models'], to: '/concepts/backends-and-models'},
          {from: ['/guides/concepts/testing'], to: '/topics/testing'},
          {from: ['/guides/concepts/debugging'], to: '/topics/debugging'},
          {from: ['/guides/concepts/error-handling'], to: '/topics/error-handling'},
          {from: ['/guides/concepts/remote-resources', '/cookbooks/remote-resources'], to: '/topics/remote-resources'},

          // Cookbook stubs that never had content now point at the real pages
          {from: ['/cookbooks/authorization'], to: '/topics/authorization'},
          {from: ['/cookbooks/caching'], to: '/topics/caching'},
          {from: ['/cookbooks/etags'], to: '/topics/etags'},
          {from: ['/cookbooks/json_attributes'], to: '/topics/json-attributes'},
          {from: ['/cookbooks/openstruct-models'], to: '/topics/openstruct-models'},
          {from: ['/cookbooks/without-activerecord'], to: '/topics/without-activerecord'},
          {from: ['/cookbooks/customizing-sideloads'], to: '/topics/customizing-sideloads'},
          {from: ['/cookbooks/hopping-relationships'], to: '/topics/hopping-relationships'},

          {from: ['/js/introduction'], to: '/js/'},
          {
            from: [
              '/js/reads/index',
              '/js/reads/filtering',
              '/js/reads/sorting',
              '/js/reads/pagination',
              '/js/reads/fieldsets',
              '/js/reads/includes',
              '/js/reads/nested-queries',
              '/js/reads/statistics',
            ],
            to: '/js/reads',
          },
          {
            from: [
              '/js/writes/index',
              '/js/writes/validations',
              '/js/writes/dirty-tracking',
              '/js/writes/nested',
              '/js/writes/deferred',
            ],
            to: '/js/writes',
          },
        ],

        // The 2.0 docs were staged under /graphiti/ for the whole beta, so
        // those URLs are in the wild. createRedirects sees every generated
        // route, which the static /1.13/ tree is not: that one is by hand.
        createRedirects(existingPath) {
          return [`/graphiti${existingPath}`];
        },
      },
    ],
  ],

  themeConfig: {
    announcementBar: {
      // Changing the id un-dismisses the bar for everyone who has closed it.
      id: 'graphiti-2-0-upgrade',
      content: `Graphiti 2.0 is out. Coming from 1.x? Start with the <a href="${baseUrl}upgrading">upgrade guide</a>.`,
      isCloseable: true,
    },
    colorMode: {
      // Dark for a first-time visitor. Flip respectPrefersColorScheme to true
      // to follow the OS setting instead, in which case defaultMode only
      // applies when the visitor has no preference either way. Once someone
      // uses the navbar toggle their choice is remembered and wins over both.
      defaultMode: 'dark',
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'Graphiti',
      logo: {alt: 'Graphiti', src: 'img/logo.png'},
      items: [
        {
          type: 'docsVersionDropdown',
          position: 'right',
          // 1.x stays as the original Jekyll site, frozen under /1.13.
          //
          // The pathname:// prefix is required. It is Docusaurus' escape hatch
          // for a path that is served statically but is not an app route:
          // without it the link renders as a react-router push, which finds no
          // match and shows the 404 page even though the file is served fine.
          // The prefix is stripped before baseUrl is applied, and it also makes
          // the link count as external, hence target '_self' to keep it from
          // opening in a new tab.
          dropdownItemsAfter: [
            {href: 'pathname:///1.13/', label: '1.x', target: '_self'},
          ],
        },
        {href: 'https://github.com/graphiti-api/graphiti', label: 'GitHub', position: 'right'},
        {href: 'https://discord.gg/wgqkMBsSRV', label: 'Discord', position: 'right'},
      ],
    },
    footer: {
      style: 'dark',
      copyright: [
        'Originally created by <a href="https://github.com/richmolj">Lee Richmond</a>,',
        '<a href="https://github.com/wadetandy">Wade Tandy</a>, and',
        '<a href="https://github.com/wagenet">Peter Wagenet</a>.',
        'Maintained by <a href="https://github.com/jkeen">Jeff Keen</a>',
        'with <a href="https://github.com/graphiti-api/graphiti/graphs/contributors">many contributors</a>.',
        '<br />Graphiti is released under the MIT license.',
      ].join(' '),
    },
    prism: {
      theme: withoutDiffDecoration(themes.oneLight),
      darkTheme: withoutDiffDecoration(codeBlockTheme(themes.oneDark, '#21252b')),
      additionalLanguages: ['ruby', 'bash', 'json', 'http', 'diff'],
    },
  },
};

module.exports = config;
