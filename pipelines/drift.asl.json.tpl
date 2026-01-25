{
  "StartAt": "ComputeDrift",
  "States": {
    "ComputeDrift": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${drift_lambda_arn}",
        "Payload.$": "$"
      },
      "Next": "DriftDecision"
    },
    "DriftDecision": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.drift_score",
          "NumericGreaterThan": 0.3,
          "Next": "TriggerRetrain"
        }
      ],
      "Default": "NoDrift"
    },
    "TriggerRetrain": {
      "Type": "Task",
      "Resource": "arn:aws:states:::states:startExecution",
      "Parameters": {
        "StateMachineArn": "${train_state_machine_arn}"
      },
      "End": true
    },
    "NoDrift": {
      "Type": "Succeed"
    }
  }
}
