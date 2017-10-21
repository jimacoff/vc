/* eslint-disable global-require */
/* eslint no-console:0 */

import 'foundation-sites/dist/css/foundation.css';
import 'foundation-sites/dist/css/foundation-float.css';
import 'fixed-data-table-2/dist/fixed-data-table.css';
import 'react-select/dist/react-select.css';
import "react-placeholder/lib/reactPlaceholder.css";
import 'react-tabs/style/react-tabs.css';
import WebpackerReact from 'webpacker-react';

let toPath = (name) => `${name.toLowerCase()}/${name.toLowerCase()}`;
let toComponent = (name) => require(`components/external/vcwiz/${toPath(name)}`).default;

const names = ['Discover', 'Filter', 'List'];

let components = _.fromPairs(_.map(names, name => [name, toComponent(name)]));
WebpackerReact.setup(components);

if (module.hot) {
  names.forEach(name => module.hot.accept(
    `components/external/vcwiz/${toPath(name)}`,
    () => WebpackerReact.renderOnHMR(toComponent(name)))
  );
}
