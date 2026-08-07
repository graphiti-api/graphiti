// @ts-check
const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Graphiti',
  tagline: 'Stylish Graph APIs',
  favicon: 'img/favicon.ico',

  url: 'https://www.graphiti.dev',
  baseUrl: '/',
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
          editUrl: 'https://github.com/graphiti-api/graphiti/tree/main/website/',
          // Unversioned docs serve at the root. Once `npm run docusaurus
          // docs:version 2.0` cuts a version, that becomes the root and the
          // working copy moves to /next — add the `versions` override then.
          
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
          {from: ['/guides/upgrading', '/guides/upgrading-2-0'], to: '/reference/upgrading-2-0'},
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

          {from: ['/js/introduction'], to: '/js'},
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
      },
    ],
  ],

  themeConfig: {
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
          // Link the guides index rather than /1.13/: static hosts read the
          // dot in "1.13" as a file extension, so /1.13/ never falls through
          // to its index.html the way /1.13/guides/ does.
          //
          // target '_self' is required. Without it the router treats this as
          // an in-app route, finds no match, and renders the 404 page even
          // though the file is served fine.
          dropdownItemsAfter: [
            {href: '/1.13/guides/', label: '1.x', target: '_self'},
          ],
        },
        {href: 'https://github.com/graphiti-api/graphiti', label: 'GitHub', position: 'right'},
        {href: 'https://discord.gg/wgqkMBsSRV', label: 'Discord', position: 'right'},
      ],
    },
    footer: {style: 'dark', copyright: `Graphiti is released under the MIT license.`},
    prism: {theme: themes.github, darkTheme: themes.dracula, additionalLanguages: ['ruby', 'bash', 'json', 'http']},
  },
};

module.exports = config;
