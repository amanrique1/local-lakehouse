from airflow.sdk import BaseOperator

from dbt.cli.main import dbtRunner, dbtRunnerResult


class DbtCoreOperator(BaseOperator):
	"""An Airflow operator for executing dbt CLI commands.

	This operator provides a programmatic interface to run dbt commands within
	Airflow DAGs using the dbt CLI runner. Supports common dbt operations like
	run, test, build, etc.

	Attributes:
		dbt_command (str): The dbt command to execute (e.g., 'run', 'test', 'build').
		dbt_project_dir (str): Path to the dbt project directory.
		dbt_profiles_dir (str): Path to the dbt profiles directory.
		target (str): The target profile to use for the dbt command.
		select (str): Node selection criteria for filtering models/tests.
		runner (dbtRunner): Instance of the dbt CLI runner.
		dbt_vars (dict): Dictionary of variables to pass to dbt.
		full_refresh (bool): Whether to perform a full refresh of incremental models.
	"""

	def __init__(
		self,
		dbt_project_dir: str,
		dbt_profiles_dir: str,
		dbt_command: str,
		target: str = None,
		select: str = None,
		dbt_vars: dict = None,
		full_refresh: bool = False,
		**kwargs,
	) -> None:
		"""Initialize the DbtCoreOperator.

		Args:
			dbt_project_dir (str): Path to the dbt project directory containing
				dbt_project.yml.
			dbt_profiles_dir (str): Path to the directory containing profiles.yaml.
			dbt_command (str): The dbt command to execute (e.g., 'run', 'test',
				'build', 'seed').
			target (str, optional): Target profile from profiles.yaml. Uses default
				if not specified.
			select (str, optional): Selection criteria for filtering nodes. Supports
				dbt selection syntax like 'model_name', 'tag:tag_name', 'path:folder/*'.
			dbt_vars (dict, optional): Variables to pass to dbt, accessible via
				{{ var('key') }}.
			full_refresh (bool, optional): If True, rebuilds incremental models
				completely. Defaults to False.
			**kwargs: Additional arguments passed to BaseOperator.
		"""
		super().__init__(**kwargs)
		self.dbt_command = dbt_command
		self.dbt_project_dir = dbt_project_dir
		self.dbt_profiles_dir = dbt_profiles_dir
		self.target = target
		self.select = select
		self.runner = dbtRunner()
		self.dbt_vars = dbt_vars or {}
		self.full_refresh = full_refresh

	def execute(self, context):
		"""Execute the dbt command with configured parameters.

		Constructs the dbt CLI command with all specified parameters, invokes
		the dbt runner, and logs the execution results.

		Args:
			context (dict): Airflow context dictionary containing task instance
				and execution metadata. Automatically provided by Airflow.

		Raises:
			Exception: Propagates exceptions from dbt CLI on command failures
				(e.g., model errors, connection failures, test failures).
		"""
		command_args = [
			self.dbt_command,
			"--profiles-dir",
			self.dbt_profiles_dir,
			"--project-dir",
			self.dbt_project_dir,
		]
		if self.target:
			command_args.extend(["--target", self.target])

		if self.select:
			command_args.extend(["--select", self.select])

		if self.full_refresh:
			command_args.extend(["--full-refresh"])

		if self.dbt_vars:
			vars_string = " ".join([f"{k}: {v}" for k, v in self.dbt_vars.items()])
			command_args.extend(["--vars", f"'{vars_string}'"])

		self.log.info("Executing dbt command: %s", " ".join(command_args))

		res: dbtRunnerResult = self.runner.invoke(command_args)

		if not res.success:
			error_message = f"dbt command failed with exception: {res.exception}"
			self.log.error(error_message)
			raise Exception(error_message)

		self.log.info("dbt command executed successfully.")

		# Log individual node results
		if res.result:
			for r in res.result:
				self.log.info(f"{r.node.name}: {r.status}")
