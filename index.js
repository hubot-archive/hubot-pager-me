/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const fs = require('fs');
const path = require('path');

module.exports = function(robot, scripts) {
  const scriptsPath = path.resolve(__dirname, 'src', 'scripts');
  return fs.exists(scriptsPath, function(exists) {
    if (exists) {
      return (() => {
        const result = [];
        for (var script of Array.from(fs.readdirSync(scriptsPath))) {
          if ((scripts != null) && !Array.from(scripts).includes('*')) {
            if (Array.from(scripts).includes(script)) { result.push(robot.loadFile(scriptsPath, script)); } else {
              result.push(undefined);
            }
          } else {
            result.push(robot.loadFile(scriptsPath, script));
          }
        }
        return result;
      })();
    }
  });
};
