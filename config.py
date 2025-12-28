import os

from typing import Literal


class Settings:
    def __init__(self):
        self.environment: Literal["development", "staging", "production"] = os.getenv(
            "ENVIRONMENT", "development"
        )
        self.app_name: str = "FastAPI CI/CD Demo"
        self.version: str = os.getenv("APP_VERSION", "2.0.0")
        self.debug: bool = self.environment == "development"
        # self.database_url: str = os.getenv('DATABASE_URL', 'sqlite:///./test.db')

    def get_info(self):
        return {
            "app": self.app_name,
            "version": self.version,
            "environment": self.environment,
            "debug": self.debug,
        }


settings = Settings()
