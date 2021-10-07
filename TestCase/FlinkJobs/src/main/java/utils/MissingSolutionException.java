package utils;

public class MissingSolutionException extends Exception {
	public MissingSolutionException() {};

	public MissingSolutionException(String message) {
		super(message);
	};

	public MissingSolutionException(Throwable cause) {
		super(cause);
	}

	public MissingSolutionException(String message, Throwable cause) {
		super(message, cause);
	}
};
