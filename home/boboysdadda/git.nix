{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "jamesAtIntegratnIO";
        email = "james@integratn.io";
      };
      alias = {
        st = "status";
        branches = "for-each-ref --sort=-committerdate refs/heads/ --format='%(authordate:short) %(color:red)%(objectname:short) %(color:yellow)%(refname:short)%(color:reset) (%(color:green)%(committerdate:relative)%(color:reset))'";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      fetch.prune = true;
    };
  };
}
