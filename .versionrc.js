const versionFileUpdater = {
    VERSION_REGEX: /VERSION = '(.+)'/,

    readVersion: function (contents) {
        const version = this.VERSION_REGEX.exec(contents)[1];
        return version;
    },

    writeVersion: function (contents, version) {
        return contents.replace(this.VERSION_REGEX.exec(contents)[0], `VERSION = '${version}'`);
    }
}

module.exports = {
    bumpFiles: [{ filename: './lib/stream-chat/version.rb', updater: versionFileUpdater }],
    types: [
        {"type": "feat", "section": "Features"},
        {"type": "fix", "section": "Bug Fixes"},
        {"type": "chore", "section": "Other", "hidden": false},
        {"type": "docs", "section": "Other", "hidden": false},
        {"type": "style", "section": "Other", "hidden": false},
        {"type": "refactor", "section": "Other", "hidden": false},
        {"type": "perf", "section": "Other", "hidden": false},
        {"type": "test", "section": "Other", "hidden": false}
    ]
}
