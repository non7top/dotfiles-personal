#!/bin/bash
# https://gist.github.com/ddepaoli3/a608046f67c7f938a1a6db6ac9529bf6

#region_name=eu-west-1
ami_id=$1
temp_snapshot_id=''

my_array=( $(aws ec2 describe-images --image-ids $ami_id --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId') )

echo "Deregistering AMI: "$ami_id
aws ec2 deregister-image --image-id $ami_id
sleep 5

echo "Removing Snapshot"

for snapshot in "${my_array[@]}"
do
    echo "Deleting Snapshot: "$snapshot
    aws ec2 delete-snapshot --snapshot-id $snapshot
done
