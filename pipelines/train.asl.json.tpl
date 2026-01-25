{
  "StartAt": "ValidateData",
  "States": {
    "ValidateData": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${validate_lambda_arn}",
        "Payload.$": "$"
      },
      "Next": "TrainModel"
    },
    "TrainModel": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${train_lambda_arn}",
        "Payload.$": "$"
      },
      "Next": "EvaluateModel"
    },
    "EvaluateModel": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.metrics.accuracy",
          "NumericGreaterThanEquals": 0.8,
          "Next": "PublishArtifacts"
        }
      ],
      "Default": "FailTraining"
    },
    "PublishArtifacts": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${publish_lambda_arn}",
        "Payload.$": "$"
      },
      "Next": "UpdateServing"
    },
    "UpdateServing": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${update_serving_lambda_arn}",
        "Payload.$": "$"
      },
      "End": true
    },
    "FailTraining": {
      "Type": "Fail",
      "Cause": "Quality gate failed"
    }
  }
}
