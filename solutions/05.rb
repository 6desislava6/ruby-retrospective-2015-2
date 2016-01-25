require 'time'
require 'digest/sha1'


class ObjectStore

  class Result
    attr_reader :message, :result
    attr_writer :result

    def initialize(message, success: true, result: nil)
      @message = message
      @success = success
      @error = ! success
      @result = result
    end

    def success?
      @success
    end

    def error?
      @error
    end
  end

  class Repository
    REMOVE = "Added %{name} for removal."
    MAKE_NEW_COMMIT = "%{message}\n\t%{changed_files} objects changed"
    COMMIT_NOT_EXITS = "Commit %{hash} does not exist."
    CHECKOUT = "HEAD is now at %{hash}."
    ADD = "Added %{name} to stage."
    COMMIT_NOTHING = "Nothing to commit, working directory clean."
    ADD_REMOVAL = "Added %{name} for removal."
    REMOVE_NOT_COMMITTED = "Object %{name} is not committed."
    BRANCH_EXISTS = "Branch %{branch_name} already exists."
    CREATED_BRANCH = "Created branch %{branch_name}."
    SWITCHED = "Switched to branch %{branch_name}."
    BRANCH_NOT_EXISTS = "Branch %{branch_name} does not exist."
    CANNOT_REMOVE_BRANCH = "Cannot remove current branch."
    REMOVED_BRANCH = "Removed branch %{branch_name}."
    BRANCH_NO_COMMITS = "Branch %{name} does not have any commits yet."
    LOG = "Commit %{hash}\nDate: %{date}\n\n\t%{message}"
    FOUND = "Found object %{name}."

    class Commit
      attr_accessor :commit_files, :hash
      attr_reader :message, :date

      def initialize(files, message)
        @hash = hash
        @commit_files = files
        @message = message
        @date = Time.new
      end

      def objects
        @commit_files.values
      end

      def to_s
        LOG % { hash: @hash, date: date.strftime("%a %b %d %H:%M %Y %z"),
               message: @message}
      end
    end

    class Branch
      attr_accessor :added_files, :removed_files, :changed_files, :commits
      attr_reader :name

      def initialize(name, commits = [])
        @name = name
        @commits = commits
      end

      def remove_file(name)
          removed = @commits.last.commit_files[name]
          Result.new(REMOVE % {name: name}, result: removed)
      end

      def make_new_commit(message, commit_files, changed_files)
        @commits << Commit.new(commit_files, message)
        hash = Digest::SHA1.hexdigest(@commits.last.date.
                                    strftime("%a %b %d %H:%M %Y %z") + message)
        @commits.last.hash = hash
        result = Result.new(MAKE_NEW_COMMIT % { message: message,
                                                changed_files: changed_files },
                                                result: @commits.last)
      end

      def checkout(hash)
        index_commit = @commits.index{|x| x.hash == hash}
        if index_commit.nil?
          Result.new(COMMIT_NOT_EXITS % { hash: hash }, success: false)
        else
          @commits = @commits.take(index_commit + 1)
          Result.new(CHECKOUT % { hash: hash }, result: @commits.last)
        end
      end
    end

    class BranchManager

      attr_reader :current_branch, :branches
      def initialize
        @current_branch = Branch.new("master")
        @branches = {"master": @current_branch}
        @added_files = {}
        @removed_files = {}
        @changed_files = 0
      end

      def add(name, object)
        @changed_files += 1 unless @added_files.has_key?(name)
        @added_files[name] = object
        message = ADD % { name: name }
        Result.new(message, result: object)
      end

      def clean_files
        @added_files = {}
        @removed_files = []
        @changed_files = 0
      end

      def remove_extra(name)
        @removed_files << name
        @changed_files += 1
      end

      def make_commit_files
        if @current_branch.commits.empty?
          data = @added_files
        else
          data = @current_branch.commits.last.commit_files.merge(@added_files)
        end
        data.delete_if{|key, value| @removed_files.member?(key)}
      end

      def commit(message)
        if @changed_files == 0
          return Result.new(COMMIT_NOTHING,
                            success: false)
        end
        make_result(message)
      end

      def make_result(message)
        result = @current_branch.make_new_commit(message,
                                        make_commit_files,
                                        @changed_files)
        clean_files
        result
      end

      def remove_in_added_files(name)
         removed = @added_files.delete(name)
         remove_extra(name)
         Result.new(ADD_REMOVAL % { name: name } , result: removed)
      end

      def remove_in_branch(name)
        remove_extra(name)
        @current_branch.remove_file(name)
      end

      def remove_file(name)
        has_commits = head.success?
        if has_commits and @current_branch.commits.last.commit_files.
                                                      has_key?(name)
          remove_in_branch(name)
        else
          return Result.new(REMOVE_NOT_COMMITTED % { name: name } ,
                            success: false)
        end
      end

      def checkout_hash(hash)
        @current_branch.checkout(hash)
      end

      def create(branch_name)
        if @branches.has_key?(branch_name.to_sym)
          Result.new(BRANCH_EXISTS % { branch_name: branch_name },
                     success: false)
        else
          new_branch = Branch.new(branch_name, @current_branch.commits.clone)
          @branches[branch_name.to_sym] = new_branch
          Result.new(CREATED_BRANCH % { branch_name: branch_name},
                     result: new_branch)
        end
      end

      def checkout(branch_name)
        if @branches.has_key?(branch_name.to_sym)
          @current_branch = @branches[branch_name.to_sym]
          Result.new(SWITCHED % { branch_name: branch_name },
                    result: @current_branch)
        else
          Result.new(BRANCH_NOT_EXISTS % { branch_name: branch_name },
                     success: false)
        end
      end

      def remove(branch_name)
        if not @branches.has_key?(branch_name.to_sym)
          Result.new(BRANCH_NOT_EXISTS % { branch_name: branch_name },
                     success: false)
        elsif @current_branch.name.to_sym == branch_name.to_sym
          Result.new(CANNOT_REMOVE_BRANCH, success: false)
        else
          Result.new(REMOVED_BRANCH % { branch_name: branch_name },
                     result: @branches.delete(branch_name.to_sym))
        end
      end

      def list
        names = @branches.keys.map(&:to_s).sort
        result = names.reduce("") do |message, name|
          if name == @current_branch.name
            message += "\n* " + name
          else
            message += "\n  " + name
          end
        end
        Result.new(result[1..-1])
      end

      def log
        if @current_branch.commits.empty?
          Result.new(BRANCH_NO_COMMITS % { name: @current_branch.name },
                     success: false)
        else
          message = @current_branch.commits.reverse.map(&:to_s).join("\n\n")
          Result.new(message.strip)
        end
      end

      def head
        if @current_branch.commits.empty?
          Result.new(BRANCH_NO_COMMITS % { name: @current_branch.name } ,
                     success: false)
        else
          last_commit = @current_branch.commits.last
          Result.new(last_commit.message, result: last_commit)
        end
      end

      def get(name)
        if @current_branch.commits.empty? or
            not @current_branch.commits.last.commit_files.has_key?(name)
          Result.new(REMOVE_NOT_COMMITTED % { name: name },
                                    success: false)
        else
          Result.new(FOUND % { name: name },
                     result: @current_branch.commits.last.commit_files[name])
        end
      end
    end

    attr_reader :branch_manager
    def initialize
      @branch_manager = BranchManager.new
    end

    def add(name, object)
      @branch_manager.add(name, object)
    end

    def commit(message)
      @branch_manager.commit(message)
    end

    def remove(name)
      @branch_manager.remove_file(name)
    end

    def checkout(hash)
      @branch_manager.checkout_hash(hash)
    end

    def branch
      @branch_manager
    end

    def log
       @branch_manager.log
    end

    def head
      @branch_manager.head
    end

    def get(name)
      @branch_manager.get(name)
    end
  end

  class << self
    def init(&block)
      repo = Repository.new
      return repo if not block_given?
      repo.instance_eval(&block)
      repo
    end
  end
end
