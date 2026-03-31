const path = require('path');

module.exports = function (robot) {
  const srcPath = path.resolve(__dirname, 'src');
  robot.loadFile(srcPath, 'pager-me.js');
  robot.loadFile(srcPath, 'pager-me-webhooks.js');
};
